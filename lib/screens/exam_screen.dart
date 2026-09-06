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
  final int durationMin;
  final String? examId;
  final String? examName;

  const ExamScreen({
    super.key,
    required this.questions,
    required this.durationMin,
    this.examId,
    this.examName,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  Timer? _timer;
  late int remainingSeconds;
  int current = 0;
  final Map<String, Set<int>> answers = {};
  final Set<String> marked = {};
  Timer? _autosaveTimer;
  DateTime? _questionStartTime;
  final Map<String, int> _timeSpent = {};
  DateTime _examStartTime = DateTime.now();
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    remainingSeconds = widget.durationMin * 60;
    for (var q in widget.questions) {
      answers[q.id] = <int>{};
      _timeSpent[q.id] = 0;
    }
    _questionStartTime = DateTime.now();
    _examStartTime = DateTime.now();
    _tryResumeSession();
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
            title: const Text('Resume previous session?'),
            content: const Text(
              'A saved session was found for this exam. Do you want to resume where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No, Start Fresh'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Resume'),
              ),
            ],
          ),
        );
        if (resume == true && mounted) {
          try {
            final savedAnswers = (session['answers'] as Map<String, dynamic>?)?.map(
              (k, v) {
                if (v is List) {
                  return MapEntry(k, v.map((e) => (e as num).toInt()).toSet());
                } else if (v is int) {
                  return MapEntry(k, {v});
                }
                return MapEntry(k, <int>{});
              },
            );
            final savedIndex = session['currentIndex'] as int?;
            final savedRem = session['remainingSeconds'] as int?;

            setState(() {
              if (savedAnswers != null) {
                for (var entry in savedAnswers.entries) {
                  if (answers.containsKey(entry.key)) {
                    answers[entry.key] = entry.value;
                  }
                }
              }
              if (savedIndex != null && savedIndex < widget.questions.length) {
                current = savedIndex;
              }
              if (savedRem != null && savedRem > 0) {
                remainingSeconds = savedRem;
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
      if (!mounted) return;
      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        } else {
          t.cancel();
          _timeUpAutoSubmit();
        }
      });
    });

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveSession());
  }

  void _timeUpAutoSubmit() {
    if (_isFinishing) return;
    _isFinishing = true;
    _trackQuestionTime();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('⏰ Time is up!'),
        content: const Text(
          'Your time has expired. Your exam will now be automatically submitted.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam(forced: true);
            },
            child: const Text('View Results'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSession() async {
    if (widget.examId == null) return;
    final map = <String, dynamic>{
      'currentIndex': current,
      'remainingSeconds': remainingSeconds,
      'answers': answers.map((k, v) => MapEntry(k, v.toList())),
      'marked': marked.toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await StorageService.saveSession(widget.examId!, map);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _autosaveTimer?.cancel();
    super.dispose();
  }

  String _formatTimer(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleOption(int index, bool isMultiple) {
    HapticFeedback.lightImpact();
    setState(() {
      final qId = widget.questions[current].id;
      final currentSet = answers[qId] ?? <int>{};
      if (isMultiple) {
        if (currentSet.contains(index)) {
          currentSet.remove(index);
        } else {
          currentSet.add(index);
        }
        answers[qId] = currentSet;
      } else {
        answers[qId] = {index};
      }
    });
  }

  void _confirmSubmit() {
    _trackQuestionTime();
    final unansweredCount = widget.questions.where((q) {
      final a = answers[q.id];
      return a == null || a.isEmpty;
    }).length;

    if (unansweredCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unanswered Questions'),
          content: Text(
            'You still have $unansweredCount unanswered question${unansweredCount > 1 ? 's' : ''}. Are you sure you want to submit?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue Exam'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () {
                Navigator.pop(ctx);
                _submitExam();
              },
              child: const Text('Submit Exam'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit Exam?'),
          content: const Text('Are you ready to submit your exam and view your score?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _submitExam();
              },
              child: const Text('Submit Exam'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _submitExam({bool forced = false}) async {
    _isFinishing = true;
    _timer?.cancel();
    _autosaveTimer?.cancel();
    _trackQuestionTime();

    if (widget.examId != null) {
      await StorageService.clearSession(widget.examId!);
    }

    final totalElapsedSeconds = DateTime.now().difference(_examStartTime).inSeconds;

    // Grade each question: exact set match
    int correctCount = 0;
    int incorrectCount = 0;
    int unansweredCount = 0;
    final Map<String, dynamic> breakdown = {};

    for (var q in widget.questions) {
      final userAnswers = answers[q.id] ?? <int>{};
      final isCorrect = q.isAnswerCorrect(userAnswers);
      final isUnanswered = userAnswers.isEmpty;

      if (isUnanswered) {
        unansweredCount++;
      } else if (isCorrect) {
        correctCount++;
      } else {
        incorrectCount++;
      }

      breakdown[q.id] = {
        'selected': userAnswers.toList(),
        'correctAnswers': q.correctAnswers.toList(),
        'isCorrect': isCorrect,
        'isUnanswered': isUnanswered,
        'timeSpent': _timeSpent[q.id] ?? 0,
      };
    }

    final perf = ExamPerformance(
      examId: widget.examId ?? 'unknown',
      examName: widget.examName ?? 'Exam',
      date: DateTime.now(),
      totalQuestions: widget.questions.length,
      correct: correctCount,
      incorrect: incorrectCount,
      unanswered: unansweredCount,
      durationSeconds: totalElapsedSeconds,
      timePerQuestion: _timeSpent,
      questionResults: {
        for (var q in widget.questions)
          q.id: q.isAnswerCorrect(answers[q.id] ?? <int>{})
      },
    );

    if (widget.examId != null) {
      await StorageService.savePerformance(perf);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          questions: widget.questions,
          answers: answers,
          timeSpentSec: totalElapsedSeconds,
          timePerQuestion: _timeSpent,
          examName: widget.examName,
          examId: widget.examId,
        ),
      ),
    );
  }

  void _showQuestionNavigatorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Question Navigator',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Legend
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildLegendItem(AppTheme.primaryNavy, Colors.white, 'Current'),
                        _buildLegendItem(const Color(0xFFDBEAFE), AppTheme.primaryNavy, 'Answered'),
                        _buildLegendItem(Colors.white, AppTheme.secondaryText, 'Unanswered', isBordered: true),
                        _buildLegendItem(const Color(0xFFFEF3C7), AppTheme.warning, 'Flagged'),
                      ],
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: GridView.builder(
                        itemCount: widget.questions.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.2,
                        ),
                        itemBuilder: (_, i) {
                          final q = widget.questions[i];
                          final isCur = i == current;
                          final isAns = (answers[q.id]?.isNotEmpty ?? false);
                          final isFlg = marked.contains(q.id);

                          Color bg = Colors.white;
                          Color fg = AppTheme.text;
                          Border? border = Border.all(color: AppTheme.border);

                          if (isCur) {
                            bg = AppTheme.primaryNavy;
                            fg = Colors.white;
                            border = null;
                          } else if (isFlg) {
                            bg = const Color(0xFFFEF3C7);
                            fg = const Color(0xFFB45309);
                            border = Border.all(color: const Color(0xFFFCD34D));
                          } else if (isAns) {
                            bg = const Color(0xFFDBEAFE);
                            fg = AppTheme.primaryNavy;
                            border = Border.all(color: const Color(0xFF93C5FD));
                          }

                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _navigateToQuestion(i);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(8),
                                border: border,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: fg,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendItem(Color bg, Color fg, String label, {bool isBordered = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: isBordered ? Border.all(color: AppTheme.border) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Mode')),
        body: const Center(child: Text('No questions available.')),
      );
    }

    final q = widget.questions[current];
    final isLast = current == widget.questions.length - 1;
    final isMultiple = q.isMultiple;
    final selected = answers[q.id] ?? <int>{};
    final questionsLeft = widget.questions.length - current - 1;
    final isFlagged = marked.contains(q.id);
    final progress = (current + 1) / widget.questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave Exam?'),
            content: const Text('Your exam session progress will be saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay in Exam'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Leave Exam'),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(widget.examName != null ? widget.examName! : 'Exam Mode'),
          actions: [
            IconButton(
              icon: Icon(
                isFlagged ? Icons.bookmark : Icons.bookmark_border,
                color: isFlagged ? AppTheme.warning : AppTheme.secondaryText,
              ),
              tooltip: 'Flag Question',
              onPressed: () {
                setState(() {
                  if (isFlagged) {
                    marked.remove(q.id);
                  } else {
                    marked.add(q.id);
                  }
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Sticky Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Question ID
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          q.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Countdown Timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: remainingSeconds < 120
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFEBF2FA),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 15,
                              color: remainingSeconds < 120 ? AppTheme.danger : AppTheme.primaryNavy,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTimer(remainingSeconds),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: remainingSeconds < 120 ? AppTheme.danger : AppTheme.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Questions Left
                      Text(
                        '$questionsLeft Left',
                        style: const TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Mode Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Exam Mode',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: AppTheme.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                    ),
                  ),
                ],
              ),
            ),

            // Question Content (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Question Card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppTheme.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isMultiple
                                            ? const Color(0xFFF3E8FF)
                                            : const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isMultiple ? 'MULTIPLE SELECT' : 'SINGLE SELECT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isMultiple
                                              ? const Color(0xFF6B21A8)
                                              : AppTheme.accentBlue,
                                        ),
                                      ),
                                    ),
                                    if (q.topic != null && q.topic!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          q.topic!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.secondaryText,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      'Question ${current + 1} of ${widget.questions.length}',
                                      style: const TextStyle(
                                        color: AppTheme.secondaryText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isMultiple) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Select all that apply.',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: AppTheme.accentBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Text(
                                  '${q.id}. ${q.question}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.text,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Options Cards
                        ...List.generate(q.options.length, (i) {
                          final isOptionSelected = selected.contains(i);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _toggleOption(i, isMultiple),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isOptionSelected
                                        ? const Color(0xFFEBF2FA)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isOptionSelected
                                          ? AppTheme.accentBlue
                                          : AppTheme.border,
                                      width: isOptionSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (isMultiple)
                                        Icon(
                                          isOptionSelected
                                              ? Icons.check_box
                                              : Icons.check_box_outline_blank,
                                          color: isOptionSelected
                                              ? AppTheme.accentBlue
                                              : AppTheme.secondaryText,
                                          size: 22,
                                        )
                                      else
                                        Icon(
                                          isOptionSelected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          color: isOptionSelected
                                              ? AppTheme.accentBlue
                                              : AppTheme.secondaryText,
                                          size: 22,
                                        ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${String.fromCharCode(65 + i)} — ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isOptionSelected
                                              ? AppTheme.accentBlue
                                              : AppTheme.text,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          q.options[i],
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isOptionSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: AppTheme.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 12),

                        // Locked Show Answer Button for Exam Mode
                        Center(
                          child: Tooltip(
                            message: 'Available only in Practice Mode',
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                foregroundColor: AppTheme.secondaryText,
                                side: const BorderSide(color: AppTheme.border),
                              ),
                              icon: const Icon(Icons.lock_outline, size: 18),
                              label: const Text(
                                'Show Answer (Available only in Practice Mode)',
                                style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                              ),
                              onPressed: null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Navigation Sticky Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Row(
                    children: [
                      // Previous Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Previous'),
                          onPressed: current > 0
                              ? () => _navigateToQuestion(current - 1)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Question Navigator Trigger Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.grid_view, size: 18),
                        label: const Text('Navigator'),
                        onPressed: _showQuestionNavigatorModal,
                      ),
                      const SizedBox(width: 12),

                      // Next / Finish Button
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isLast ? AppTheme.accentBlue : AppTheme.primaryNavy,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(isLast ? Icons.check_circle_outline : Icons.arrow_forward, size: 18),
                          label: Text(isLast ? 'Finish Exam' : 'Next'),
                          onPressed: () {
                            if (isLast) {
                              _confirmSubmit();
                            } else {
                              _navigateToQuestion(current + 1);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
