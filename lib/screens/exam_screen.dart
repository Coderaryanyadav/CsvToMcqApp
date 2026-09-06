import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/performance.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';
import '../services/storage_service.dart';

class ExamScreen extends StatefulWidget {
  final List<Question> questions;
  final int durationMin; // 0 or negative = Untimed
  final String? examId;
  final String? examName;
  final int passingPercentage;

  const ExamScreen({
    super.key,
    required this.questions,
    required this.durationMin,
    this.examId,
    this.examName,
    this.passingPercentage = 75,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  Timer? _timer;
  late int _remainingSeconds;
  int _elapsedSeconds = 0;
  int current = 0;
  final Map<String, Set<int>> answers = {};
  final Set<String> marked = {};
  Timer? _autosaveTimer;
  DateTime? _questionStartTime;
  final Map<String, int> _timeSpent = {};
  bool _isFinishing = false;
  final FocusNode _focusNode = FocusNode();

  bool get isUntimed => widget.durationMin <= 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.durationMin * 60;
    for (var q in widget.questions) {
      answers[q.id] = <int>{};
      _timeSpent[q.id] = 0;
    }
    _questionStartTime = DateTime.now();
    _tryResumeSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _autosaveTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _trackQuestionTime() {
    if (_questionStartTime != null && current < widget.questions.length) {
      final qId = widget.questions[current].id;
      final elapsed = DateTime.now().difference(_questionStartTime!).inSeconds;
      _timeSpent[qId] = (_timeSpent[qId] ?? 0) + elapsed;
    }
    _questionStartTime = DateTime.now();
  }

  void _navigateToQuestion(int index) {
    if (index >= 0 && index < widget.questions.length) {
      _trackQuestionTime();
      setState(() {
        current = index;
      });
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _tryResumeSession() async {
    if (widget.examId != null) {
      final session = await StorageService.readSession(widget.examId!);
      if (session != null && mounted) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resume Previous Session?'),
            content: const Text(
              'A saved session was found for this exam. Do you want to resume where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Start Fresh'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Resume Session'),
              ),
            ],
          ),
        );

        if (resume == true && mounted) {
          try {
            final savedAnswers =
                (session['answers'] as Map<String, dynamic>?)?.map(
              (k, v) {
                if (v is List) {
                  return MapEntry(k, v.map((e) => (e as num).toInt()).toSet());
                } else if (v is int) {
                  return MapEntry(k, {v});
                }
                return MapEntry(k, <int>{});
              },
            );
            final savedMarked = (session['marked'] as List?)?.cast<String>();
            final savedIndex = session['currentIndex'] as int?;
            final savedRem = session['remainingSeconds'] as int?;
            final savedElapsed = session['elapsedSeconds'] as int?;

            setState(() {
              if (savedAnswers != null) {
                for (var entry in savedAnswers.entries) {
                  if (answers.containsKey(entry.key)) {
                    answers[entry.key] = entry.value;
                  }
                }
              }
              if (savedMarked != null) {
                marked.addAll(savedMarked);
              }
              if (savedIndex != null && savedIndex < widget.questions.length) {
                current = savedIndex;
              }
              if (savedRem != null && savedRem > 0) {
                _remainingSeconds = savedRem;
              }
              if (savedElapsed != null && savedElapsed > 0) {
                _elapsedSeconds = savedElapsed;
              }
            });
          } catch (_) {}
        }
      }
    }

    if (mounted) {
      _startTimers();
    }
  }

  void _startTimers() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _isFinishing) {
        t.cancel();
        return;
      }
      if (isUntimed) {
        setState(() {
          _elapsedSeconds++;
        });
      } else {
        if (_remainingSeconds > 1) {
          setState(() {
            _remainingSeconds--;
            _elapsedSeconds++;
          });
        } else {
          t.cancel();
          setState(() {
            _remainingSeconds = 0;
            _elapsedSeconds++;
          });
          _timeUpAutoSubmit();
        }
      }
    });

    _autosaveTimer?.cancel();
    _autosaveTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _saveSession());
  }

  Future<void> _saveSession() async {
    if (widget.examId == null || _isFinishing) return;
    _trackQuestionTime();
    final sessionData = {
      'examId': widget.examId,
      'questionIds': widget.questions.map((q) => q.id).toList(),
      'currentIndex': current,
      'answers': answers.map((k, v) => MapEntry(k, v.toList())),
      'marked': marked.toList(),
      'remainingSeconds': _remainingSeconds,
      'elapsedSeconds': _elapsedSeconds,
      'timeSpent': _timeSpent,
      'lastSavedAt': DateTime.now().toIso8601String(),
    };
    await StorageService.saveSession(widget.examId!, sessionData);
  }

  void _timeUpAutoSubmit() {
    if (_isFinishing) return;
    _isFinishing = true;
    _timer?.cancel();
    _autosaveTimer?.cancel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Time is up! Submitting and grading your exam...'),
          backgroundColor: AppTheme.danger,
          duration: Duration(seconds: 2),
        ),
      );
    }
    _submitExam(forced: true);
  }

  Future<void> _submitExam({bool forced = false}) async {
    if (_isFinishing) return;

    if (!forced) {
      final unansweredCount =
          widget.questions.where((q) => answers[q.id]?.isEmpty ?? true).length;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit Exam?'),
          content: Text(
            unansweredCount > 0
                ? 'You have $unansweredCount unanswered question(s). Are you sure you want to finish and submit now?'
                : 'Are you sure you want to finish and submit your exam?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continue Reviewing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit Exam'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    _isFinishing = true;
    _timer?.cancel();
    _autosaveTimer?.cancel();
    _trackQuestionTime();

    int correct = 0;
    int incorrect = 0;
    int unanswered = 0;
    final Map<String, bool> results = {};
    final Map<String, int> topicTotals = {};
    final Map<String, int> topicCorrect = {};

    for (var q in widget.questions) {
      final userSelection = answers[q.id] ?? <int>{};
      final topic = q.topic ?? 'General';
      topicTotals[topic] = (topicTotals[topic] ?? 0) + 1;

      if (userSelection.isEmpty) {
        unanswered++;
        results[q.id] = false;
      } else if (q.isAnswerCorrect(userSelection)) {
        correct++;
        results[q.id] = true;
        topicCorrect[topic] = (topicCorrect[topic] ?? 0) + 1;
      } else {
        incorrect++;
        results[q.id] = false;
      }
    }

    final weak = <String>[];
    topicTotals.forEach((t, tot) {
      final c = topicCorrect[t] ?? 0;
      if ((c / tot) < 0.65) weak.add(t);
    });

    final activeStudent = await StorageService.getActiveStudent();

    final perf = ExamPerformance(
      studentId: activeStudent?.id,
      studentName: activeStudent?.name,
      examId: widget.examId ?? 'custom_exam',
      examName: widget.examName ?? 'Exam Simulation',
      date: DateTime.now(),
      totalQuestions: widget.questions.length,
      correct: correct,
      incorrect: incorrect,
      unanswered: unanswered,
      durationSeconds: _elapsedSeconds,
      timePerQuestion: _timeSpent,
      questionResults: results,
      weakTopics: weak,
      passingPercentage: widget.passingPercentage,
    );

    await StorageService.savePerformance(perf);
    if (widget.examId != null) {
      await StorageService.clearSession(widget.examId!);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          questions: widget.questions,
          answers: answers,
          timePerQuestion: _timeSpent,
          timeSpentSec: _elapsedSeconds,
          examName: widget.examName,
          examId: widget.examId,
          passingPercentage: widget.passingPercentage,
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.digit1 ||
        event.logicalKey == LogicalKeyboardKey.keyA) {
      _selectOption(0);
    } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.keyB) {
      _selectOption(1);
    } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
        event.logicalKey == LogicalKeyboardKey.keyC) {
      _selectOption(2);
    } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
        event.logicalKey == LogicalKeyboardKey.keyD) {
      _selectOption(3);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (current < widget.questions.length - 1) {
        _navigateToQuestion(current + 1);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (current > 0) {
        _navigateToQuestion(current - 1);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
      _toggleBookmark();
    }
  }

  void _selectOption(int optIdx) {
    final q = widget.questions[current];
    if (optIdx >= q.options.length) return;

    setState(() {
      final currentAns = answers[q.id] ?? <int>{};
      if (q.isMultiple) {
        if (currentAns.contains(optIdx)) {
          currentAns.remove(optIdx);
        } else {
          currentAns.add(optIdx);
        }
        answers[q.id] = currentAns;
      } else {
        answers[q.id] = {optIdx};
      }
    });
    HapticFeedback.selectionClick();
  }

  void _toggleBookmark() {
    final qId = widget.questions[current].id;
    setState(() {
      if (marked.contains(qId)) {
        marked.remove(qId);
      } else {
        marked.add(qId);
      }
    });
    HapticFeedback.lightImpact();
  }

  Color _getTimerColor() {
    if (isUntimed) return AppTheme.accentBlue;
    if (_remainingSeconds <= 10) return AppTheme.danger;
    if (_remainingSeconds <= 60) return AppTheme.danger;
    if (_remainingSeconds <= 300) return AppTheme.warning;
    return AppTheme.text;
  }

  String _formatTimerText() {
    if (isUntimed) {
      final h = _elapsedSeconds ~/ 3600;
      final m = (_elapsedSeconds % 3600) ~/ 60;
      final s = _elapsedSeconds % 60;
      if (h > 0) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showQuestionNavigatorSheet(BuildContext context, bool isDark) {
    final answeredCount = widget.questions
        .where((item) => answers[item.id]?.isNotEmpty ?? false)
        .length;
    final totalCount = widget.questions.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Question Navigator',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$answeredCount of $totalCount answered',
                            style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: totalCount,
                    itemBuilder: (context, idx) {
                      final itemQ = widget.questions[idx];
                      final isAns = answers[itemQ.id]?.isNotEmpty ?? false;
                      final isCurr = idx == current;
                      final isMark = marked.contains(itemQ.id);

                      Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
                      Color textC = isDark ? Colors.white : AppTheme.text;
                      BorderSide borderSide = BorderSide.none;

                      if (isCurr) {
                        borderSide = const BorderSide(color: AppTheme.accentBlue, width: 2);
                      }

                      if (isAns) {
                        bg = AppTheme.success.withValues(alpha: 0.18);
                        textC = AppTheme.success;
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.pop(ctx);
                          _navigateToQuestion(idx);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: borderSide.color,
                              width: borderSide.width,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontWeight: isCurr ? FontWeight.bold : FontWeight.w600,
                                  color: textC,
                                  fontSize: 14,
                                ),
                              ),
                              if (isMark)
                                const Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Icon(Icons.bookmark, size: 12, color: AppTheme.warning),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;

    final q = widget.questions[current];
    final userAns = answers[q.id] ?? <int>{};
    final isBookmarked = marked.contains(q.id);

    final answeredCount = widget.questions
        .where((item) => answers[item.id]?.isNotEmpty ?? false)
        .length;
    final totalCount = widget.questions.length;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final exit = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Exit Exam?'),
              content: const Text(
                'Your progress will be saved automatically so you can resume later.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Resume Exam'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save & Exit'),
                ),
              ],
            ),
          );
          if (exit == true) {
            await _saveSession();
            if (!context.mounted) return;
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.examName ?? 'Exam Mode',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: isMobile ? 16 : 18),
            ),
            actions: [
              // Timer Display
              Container(
                margin: EdgeInsets.only(right: isMobile ? 6 : 12),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _getTimerColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getTimerColor().withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUntimed ? Icons.timelapse : Icons.timer,
                      color: _getTimerColor(),
                      size: isMobile ? 15 : 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimerText(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 14,
                        color: _getTimerColor(),
                      ),
                    ),
                  ],
                ),
              ),

              // Mobile Grid Navigator Icon
              if (isMobile)
                IconButton(
                  tooltip: 'Questions Grid',
                  icon: const Icon(Icons.grid_view_rounded, size: 20),
                  onPressed: () => _showQuestionNavigatorSheet(context, isDark),
                ),

              // Finish Exam Button
              Padding(
                padding: EdgeInsets.only(right: isMobile ? 8 : 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 16,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _submitExam(),
                  child: Text(
                    isMobile ? 'Finish' : 'Finish Exam',
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              // Main Question Area
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 28,
                    vertical: isMobile ? 16 : 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Question Meta Row
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 8 : 12,
                                  vertical: isMobile ? 4 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Question ${current + 1} of $totalCount',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 12 : 13,
                                  ),
                                ),
                              ),
                              if (q.topic != null) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Chip(
                                    label: Text(
                                      q.topic!,
                                      style: TextStyle(fontSize: isMobile ? 11 : 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              IconButton.filledTonal(
                                tooltip: isBookmarked
                                    ? 'Unmark Question'
                                    : 'Mark for Review (M)',
                                icon: Icon(
                                  isBookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: isBookmarked
                                      ? AppTheme.warning
                                      : Colors.grey,
                                  size: isMobile ? 18 : 22,
                                ),
                                onPressed: _toggleBookmark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Question Text
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(isMobile ? 16 : 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (q.isMultiple)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'MULTIPLE SELECT (Choose all that apply)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.accentBlue,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    q.question,
                                    style: TextStyle(
                                      fontSize: isMobile ? 15 : 17,
                                      fontWeight: FontWeight.w600,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Options List
                          ...List.generate(q.options.length, (optIdx) {
                            final isSelected = userAns.contains(optIdx);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _selectOption(optIdx),
                                child: Container(
                                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.accentBlue.withValues(alpha: 0.08)
                                        : (isDark
                                            ? AppTheme.darkSurface
                                            : Colors.white),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.accentBlue
                                          : (isDark
                                              ? AppTheme.darkBorder
                                              : AppTheme.border),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: isMobile ? 28 : 32,
                                        height: isMobile ? 28 : 32,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.accentBlue
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.accentBlue
                                                : (isDark
                                                    ? AppTheme.darkSecondaryText
                                                    : AppTheme.secondaryText),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            String.fromCharCode(65 + optIdx),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: isMobile ? 12 : 14,
                                              color: isSelected
                                                  ? Colors.white
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          q.options[optIdx],
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 20),

                          // Navigation Bottom Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(
                                icon: Icon(Icons.arrow_back, size: isMobile ? 16 : 18),
                                label: Text(isMobile ? 'Prev' : 'Previous'),
                                onPressed: current > 0
                                    ? () => _navigateToQuestion(current - 1)
                                    : null,
                              ),
                              if (current < totalCount - 1)
                                FilledButton.icon(
                                  icon: Icon(Icons.arrow_forward, size: isMobile ? 16 : 18),
                                  label: Text(isMobile ? 'Next' : 'Next Question'),
                                  onPressed: () =>
                                      _navigateToQuestion(current + 1),
                                )
                              else
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.success),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Finish Exam'),
                                  onPressed: () => _submitExam(),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Desktop Side Question Grid Navigator (Hidden on Mobile)
              if (!isMobile)
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    border: Border(
                      left: BorderSide(
                        color: isDark ? AppTheme.darkBorder : AppTheme.border,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.border,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Question Navigator',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$answeredCount of $totalCount answered',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.secondaryText),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: totalCount,
                          itemBuilder: (context, idx) {
                            final itemQ = widget.questions[idx];
                            final isAns =
                                answers[itemQ.id]?.isNotEmpty ?? false;
                            final isCurr = idx == current;
                            final isMark = marked.contains(itemQ.id);

                            Color bg = isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9);
                            Color textC = isDark ? Colors.white : AppTheme.text;
                            BorderSide borderSide = BorderSide.none;

                            if (isCurr) {
                              borderSide = const BorderSide(
                                  color: AppTheme.accentBlue, width: 2);
                            }

                            if (isAns) {
                              bg = AppTheme.success.withValues(alpha: 0.15);
                              textC = AppTheme.success;
                            }

                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _navigateToQuestion(idx),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: borderSide.color,
                                    width: borderSide.width,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        fontWeight: isCurr
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: textC,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (isMark)
                                      const Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Icon(Icons.bookmark,
                                            size: 10, color: AppTheme.warning),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
