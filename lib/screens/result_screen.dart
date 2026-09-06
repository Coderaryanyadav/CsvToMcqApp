import 'package:flutter/material.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import 'practice_mode_screen.dart';

class ResultScreen extends StatefulWidget {
  final List<Question> questions;
  final Map<String, dynamic> answers;
  final Map<String, int>? timePerQuestion;
  final int? timeSpentSec;
  final String? examName;
  final String? examId;

  const ResultScreen({
    super.key,
    required this.questions,
    required this.answers,
    this.timePerQuestion,
    this.timeSpentSec,
    this.examName,
    this.examId,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Set<int> _getUserSelection(String questionId) {
    final raw = widget.answers[questionId];
    if (raw == null) return <int>{};
    if (raw is Set<int>) return raw;
    if (raw is List) return raw.map((e) => (e as num).toInt()).toSet();
    if (raw is int) return {raw};
    return <int>{};
  }

  bool _isQuestionCorrect(Question q) {
    final userSelection = _getUserSelection(q.id);
    return q.isAnswerCorrect(userSelection);
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    int correct = 0;
    int incorrect = 0;
    int unanswered = 0;
    final List<Question> mistakes = [];

    for (var q in widget.questions) {
      final userSelection = _getUserSelection(q.id);
      if (userSelection.isEmpty) {
        unanswered++;
        mistakes.add(q);
      } else if (_isQuestionCorrect(q)) {
        correct++;
      } else {
        incorrect++;
        mistakes.add(q);
      }
    }

    final total = widget.questions.length;
    final scorePct = total > 0 ? ((correct / total) * 100).round() : 0;
    final passed = scorePct >= 75;
    final totalTime = widget.timeSpentSec ??
        (widget.timePerQuestion?.values.fold<int>(0, (a, b) => a + b) ?? 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.examName != null ? '${widget.examName} Results' : 'Your Results'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryNavy,
          unselectedLabelColor: AppTheme.secondaryText,
          indicatorColor: AppTheme.accentBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Review Answers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: SUMMARY
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Heading & Score Hero Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              passed ? 'PASSED' : 'NEEDS IMPROVEMENT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$scorePct%',
                            style: const TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$correct / $total Correct',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDBEAFE),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Stats Badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatHero('Correct', '$correct', AppTheme.success),
                              _buildStatHero('Incorrect', '$incorrect', AppTheme.danger),
                              _buildStatHero('Unanswered', '$unanswered', AppTheme.warning),
                              if (totalTime > 0)
                                _buildStatHero('Time Used', _formatTime(totalTime), const Color(0xFF60A5FA)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Performance Breakdown by Topic Card
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
                            const Text(
                              'Topic Performance Breakdown',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._buildTopicBreakdown(widget.questions),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        if (mistakes.isNotEmpty) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.replay),
                              label: Text('Practice ${mistakes.length} Mistakes'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PracticeModeScreen(
                                      questions: mistakes,
                                      durationMin: 15,
                                      examName: '${widget.examName ?? "Exam"} Mistakes',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Review Answers'),
                            onPressed: () {
                              _tabController.animateTo(1);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // TAB 2: REVIEW ANSWERS
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            itemCount: widget.questions.length,
            itemBuilder: (context, i) {
              final q = widget.questions[i];
              final userSelection = _getUserSelection(q.id);
              final isCorrect = _isQuestionCorrect(q);
              final isUnanswered = userSelection.isEmpty;

              Color borderColor = isCorrect
                  ? AppTheme.success
                  : (isUnanswered ? AppTheme.warning : AppTheme.danger);
              Color bgColor = isCorrect
                  ? const Color(0xFFF0FDF4)
                  : (isUnanswered ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2));

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: borderColor.withValues(alpha: 0.4), width: 1.5),
                    ),
                    color: bgColor.withValues(alpha: 0.35),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question Header Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isCorrect
                                    ? Icons.check_circle
                                    : (isUnanswered ? Icons.help_outline : Icons.cancel),
                                color: borderColor,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: borderColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  q.id,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: borderColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  q.isMultiple ? 'MULTIPLE SELECT' : 'SINGLE SELECT',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryText,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                isCorrect ? 'Correct' : (isUnanswered ? 'Unanswered' : 'Incorrect'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: borderColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Question Text
                          Text(
                            q.question,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Options & Explanations
                          ...List.generate(q.options.length, (optIdx) {
                            final isUserChoice = userSelection.contains(optIdx);
                            final isCorrectOption = q.correctAnswers.contains(optIdx);
                            final explanation = q.getExplanation(optIdx);

                            Color optBg = Colors.white;
                            Color optBorder = AppTheme.border;
                            Widget? optIcon;

                            if (isCorrectOption) {
                              optBg = const Color(0xFFF0FDF4);
                              optBorder = const Color(0xFF86EFAC);
                              optIcon = const Icon(Icons.check_circle, color: AppTheme.success, size: 18);
                            } else if (isUserChoice) {
                              optBg = const Color(0xFFFEF2F2);
                              optBorder = const Color(0xFFFCA5A5);
                              optIcon = const Icon(Icons.cancel, color: AppTheme.danger, size: 18);
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: optBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: optBorder, width: isUserChoice || isCorrectOption ? 1.5 : 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (optIcon != null) ...[
                                        optIcon,
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        '${String.fromCharCode(65 + optIdx)} — ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isCorrectOption
                                              ? AppTheme.success
                                              : (isUserChoice ? AppTheme.danger : AppTheme.text),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          q.options[optIdx],
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isUserChoice || isCorrectOption
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: AppTheme.text,
                                          ),
                                        ),
                                      ),
                                      if (isUserChoice)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isCorrectOption
                                                ? const Color(0xFFDCFCE7)
                                                : const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Your Choice',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isCorrectOption
                                                  ? const Color(0xFF14532D)
                                                  : const Color(0xFF7F1D1D),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (explanation != null && explanation.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Explanation: ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppTheme.secondaryText,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              explanation,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.text,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatHero(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF93C5FD),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTopicBreakdown(List<Question> questions) {
    final Map<String, List<Question>> topicMap = {};
    for (var q in questions) {
      final t = q.topic != null && q.topic!.isNotEmpty ? q.topic! : 'General';
      topicMap.putIfAbsent(t, () => []).add(q);
    }

    return topicMap.entries.map((entry) {
      final topicName = entry.key;
      final topicQuestions = entry.value;
      int topicCorrect = 0;
      for (var q in topicQuestions) {
        if (_isQuestionCorrect(q)) topicCorrect++;
      }
      final pct = (topicCorrect / topicQuestions.length * 100).round();

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  topicName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.text),
                ),
                Text(
                  '$topicCorrect / ${topicQuestions.length} ($pct%)',
                  style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: topicCorrect / topicQuestions.length,
                minHeight: 6,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 75 ? AppTheme.success : (pct >= 50 ? AppTheme.warning : AppTheme.danger),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
