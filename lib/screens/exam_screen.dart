import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/performance.dart';
import '../models/question.dart';
import 'result_screen.dart';
import '../services/storage_service.dart';

// ignore_for_file: use_build_context_synchronously, deprecated_member_use

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
  DateTime? _pauseTime;
  int current = 0;
  Map<String, int?> answers = {};
  Set<String> marked = {};
  Timer? _autosaveTimer;
  DateTime? _questionStartTime;
  final Map<String, int> _timeSpent = {};
  DateTime _examStartTime = DateTime.now();
  bool navigatorCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    remainingSeconds = widget.durationMin * 60;
    for (var q in widget.questions) {
      answers[q.id] = null;
      _timeSpent[q.id] = 0;
    }
    _questionStartTime = DateTime.now();
    _examStartTime = DateTime.now();
    _tryResumeSession().then((_) {
      if (!mounted) return;
      _startTimers();
    });
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
    if (widget.examId == null) return;
    final session = await StorageService.readSession(widget.examId!);
    if (session == null) return;
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
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume == true) {
      try {
        remainingSeconds = session['remainingSeconds'] ?? remainingSeconds;
        current = session['current'] ?? current;
        final Map m = session['answers'] ?? {};
        answers = m.map(
          (k, v) => MapEntry(k as String, v == null ? null : (v as int)),
        );
        final lm = session['marked'] as List?;
        if (lm != null) marked = Set.from(lm.map((e) => e.toString()));
        setState(() {});
      } catch (e) {
        // ignore parse errors
      }
    } else {
      await StorageService.clearSession(widget.examId!);
    }
  }

  void _startTimers() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        finishExam();
      }
    });
    _autosaveTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _autosave());
  }

  void _autosave() async {
    if (widget.examId == null) return;
    final session = {
      'remainingSeconds': remainingSeconds,
      'current': current,
      'answers': answers,
      'marked': marked.toList(),
    };
    await StorageService.saveSession(widget.examId!, session);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _autosaveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pauseTime != null) {
        final elapsed = DateTime.now().difference(_pauseTime!).inSeconds;
        setState(() {
          remainingSeconds -= elapsed;
          if (remainingSeconds < 0) remainingSeconds = 0;
        });
        _pauseTime = null;
      }
    }
  }

  void selectAnswer(int idx) {
    final qid = widget.questions[current].id;
    answers[qid] = idx;
    setState(() {});
    HapticFeedback.lightImpact();
  }

  void toggleMark() {
    final qid = widget.questions[current].id;
    setState(() {
      if (marked.contains(qid)) {
        marked.remove(qid);
      } else {
        marked.add(qid);
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _showFinishDialog() {
    final answeredCount = answers.values.where((a) => a != null).length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish Exam?'),
        content: Text(
          'You have answered $answeredCount out of ${widget.questions.length} questions.\n\nAre you sure you want to finish?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              finishExam();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  void finishExam() async {
    _trackQuestionTime();
    _timer?.cancel();
    _autosaveTimer?.cancel();

    int correct = 0;
    int incorrect = 0;
    int unanswered = 0;
    final questionResults = <String, bool>{};
    for (var q in widget.questions) {
      final answer = answers[q.id];
      if (answer == null) {
        unanswered++;
      } else if (answer == q.correct) {
        correct++;
        questionResults[q.id] = true;
      } else {
        incorrect++;
        questionResults[q.id] = false;
      }
    }
    final duration = DateTime.now().difference(_examStartTime).inSeconds;

    if (widget.examId != null && widget.examName != null) {
      final performance = ExamPerformance(
        examId: widget.examId!,
        examName: widget.examName!,
        date: DateTime.now(),
        totalQuestions: widget.questions.length,
        correct: correct,
        incorrect: incorrect,
        unanswered: unanswered,
        durationSeconds: duration,
        timePerQuestion: _timeSpent,
        questionResults: questionResults,
      );
      await StorageService.savePerformance(performance);
    }

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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[current];
    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;
    final progress = (current + 1) / widget.questions.length;
    final answeredCount = answers.values.where((a) => a != null).length;
    final isLastQuestion = current == widget.questions.length - 1;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        title: Text(
          'Question ${current + 1} of ${widget.questions.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Pause/Resume',
            icon: Icon(
              _timer == null ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
            ),
            onPressed: () {
              if (_timer == null) {
                _startTimers();
              } else {
                _timer?.cancel();
                _timer = null;
              }
            },
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: remainingSeconds < 60
                  ? Colors.red.shade700
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 0) {
              _navigateToQuestion(current - 1);
            } else if (details.primaryVelocity! < 0) {
              if (!isLastQuestion) {
                _navigateToQuestion(current + 1);
              } else {
                _showFinishDialog();
              }
            }
          }
        },
        child: Column(
          children: [
            SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade300,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Q${current + 1}',
                                  style: TextStyle(
                                    color: Colors.deepPurple.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (marked.contains(q.id))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bookmark,
                                        size: 16,
                                        color: Colors.orange.shade900,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Marked',
                                        style: TextStyle(
                                          color: Colors.orange.shade900,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            q.question,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...List.generate(4, (i) {
                      final sel = answers[q.id];
                      final isSelected = sel == i;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => selectAnswer(i),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.deepPurple.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.deepPurple
                                      : Colors.grey.shade300,
                                  width: isSelected
                                      ? 2.5
                                      : 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.deepPurple
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.deepPurple
                                            : Colors.grey.shade400,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 18,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      q.options[i],
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
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
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: current > 0
                                ? () => _navigateToQuestion(current - 1)
                                : null,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Previous'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (isLastQuestion) {
                                _showFinishDialog();
                              } else {
                                _navigateToQuestion(current + 1);
                              }
                            },
                            icon: Icon(
                              isLastQuestion
                                  ? Icons.check_circle
                                  : Icons.arrow_forward,
                            ),
                            label: Text(isLastQuestion ? 'Finish' : 'Next'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLastQuestion
                                  ? Colors.green
                                  : Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: toggleMark,
                        icon: Icon(
                          marked.contains(q.id)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                        ),
                        label: Text(
                          marked.contains(q.id) ? 'Unmark' : 'Mark for Review',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: marked.contains(q.id)
                              ? Colors.orange.shade900
                              : Colors.deepPurple,
                          side: BorderSide(
                            color: marked.contains(q.id)
                                ? Colors.orange
                                : Colors.deepPurple,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Question Navigator',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$answeredCount/${widget.questions.length} answered',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => navigatorCollapsed = !navigatorCollapsed),
                        icon: Icon(
                          navigatorCollapsed ? Icons.expand_less : Icons.expand_more,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  if (!navigatorCollapsed) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.questions.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final qq = entry.value;
                            final a = answers[qq.id];
                            final isMarked = marked.contains(qq.id);
                            final isCurrent = idx == current;
                            return GestureDetector(
                              onTap: () => _navigateToQuestion(idx),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? Colors.deepPurple
                                      : a != null
                                          ? Colors.green.shade100
                                          : isMarked
                                              ? Colors.orange.shade100
                                              : Colors.grey.shade50,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCurrent
                                        ? Colors.deepPurple.shade900
                                        : a != null
                                            ? Colors.green.shade600
                                            : isMarked
                                                ? Colors.orange.shade600
                                                : Colors.grey.shade400,
                                    width: isCurrent ? 2.5 : 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: TextStyle(
                                      color: isCurrent
                                          ? Colors.white
                                          : a != null
                                              ? Colors.green.shade900
                                              : isMarked
                                                  ? Colors.orange.shade900
                                                  : Colors.black87,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showFinishDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Finish Exam',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
