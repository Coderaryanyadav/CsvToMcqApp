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
  final int passingPercentage;

  const ResultScreen({
    super.key,
    required this.questions,
    required this.answers,
    this.timePerQuestion,
    this.timeSpentSec,
    this.examName,
    this.examId,
    this.passingPercentage = 75,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _reviewFilter = 'All'; // All | Wrong | Skipped | Correct

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

  String _formatTimeDuration(int sec) {
    if (sec <= 0) return '0s';
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0 && s > 0) {
      return '${m}m ${s}s';
    } else if (m > 0) {
      return '${m}m';
    } else {
      return '${s}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
    final passed = scorePct >= widget.passingPercentage;
    final totalTime = widget.timeSpentSec ??
        (widget.timePerQuestion?.values.fold<int>(0, (a, b) => a + b) ?? 0);
    final avgTimePerQuestion = total > 0 ? (totalTime / total).round() : 0;

    // Filter questions for review tab
    final reviewQuestions = widget.questions.where((q) {
      final userSelection = _getUserSelection(q.id);
      if (_reviewFilter == 'Correct') {
        return userSelection.isNotEmpty && _isQuestionCorrect(q);
      } else if (_reviewFilter == 'Wrong') {
        return userSelection.isNotEmpty && !_isQuestionCorrect(q);
      } else if (_reviewFilter == 'Skipped') {
        return userSelection.isEmpty;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examName != null
            ? '${widget.examName} Results'
            : 'Exam Results'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.accentBlue,
          unselectedLabelColor:
              isDark ? AppTheme.darkSecondaryText : AppTheme.secondaryText,
          indicatorColor: AppTheme.accentBlue,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF1E293B),
                                  const Color(0xFF0F172A)
                                ]
                              : [
                                  const Color(0xFF0F172A),
                                  const Color(0xFF1E3A8A)
                                ],
                        ),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  passed ? AppTheme.success : AppTheme.danger,
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
                              letterSpacing: -1.5,
                            ),
                          ),
                          Text(
                            '$correct out of $total questions answered correctly',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Required passing threshold: ${widget.passingPercentage}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Metrics Grid (Correct, Incorrect, Skipped, Time)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Correct',
                            value: '$correct',
                            color: AppTheme.success,
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Incorrect',
                            value: '$incorrect',
                            color: AppTheme.danger,
                            icon: Icons.cancel_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Skipped',
                            value: '$unanswered',
                            color: AppTheme.warning,
                            icon: Icons.help_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Total Time',
                            value: _formatTimeDuration(totalTime),
                            subtitle:
                                '${_formatTimeDuration(avgTimePerQuestion)}/q',
                            color: AppTheme.accentBlue,
                            icon: Icons.timer_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Actions Row (Practice Mistakes, Review, Done)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        if (mistakes.isNotEmpty)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.accentBlue,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            icon:
                                const Icon(Icons.psychology_outlined, size: 20),
                            label: Text('Practice ${mistakes.length} Mistakes'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PracticeModeScreen(
                                    questions: mistakes,
                                    examName:
                                        '${widget.examName ?? "Exam"} - Mistakes Practice',
                                  ),
                                ),
                              );
                            },
                          ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                          ),
                          icon: const Icon(Icons.list_alt, size: 20),
                          label: const Text('Review All Answers'),
                          onPressed: () {
                            _tabController.animateTo(1);
                          },
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                          ),
                          icon: const Icon(Icons.home_outlined, size: 20),
                          label: const Text('Home Dashboard'),
                          onPressed: () {
                            Navigator.popUntil(
                                context, (route) => route.isFirst);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // TAB 2: REVIEW ANSWERS
          Column(
            children: [
              // Filter Chips Row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  border: Border(
                      bottom: BorderSide(
                          color:
                              isDark ? AppTheme.darkBorder : AppTheme.border)),
                ),
                child: Row(
                  children: [
                    const Text('Filter: ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 8,
                      children: ['All', 'Wrong', 'Skipped', 'Correct'].map((f) {
                        final isSel = _reviewFilter == f;
                        return ChoiceChip(
                          label: Text(f),
                          selected: isSel,
                          onSelected: (v) => setState(() => _reviewFilter = f),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Questions Review List
              Expanded(
                child: reviewQuestions.isEmpty
                    ? Center(
                        child: Text(
                          'No questions match the filter "$_reviewFilter".',
                          style: const TextStyle(color: AppTheme.secondaryText),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: reviewQuestions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, idx) {
                          final q = reviewQuestions[idx];
                          final userSelection = _getUserSelection(q.id);
                          final isCorr = _isQuestionCorrect(q);
                          final isSkipped = userSelection.isEmpty;

                          return _buildQuestionReviewCard(
                            q: q,
                            questionNumber: idx + 1,
                            userSelection: userSelection,
                            isCorrect: isCorr,
                            isSkipped: isSkipped,
                            isDark: isDark,
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.secondaryText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionReviewCard({
    required Question q,
    required int questionNumber,
    required Set<int> userSelection,
    required bool isCorrect,
    required bool isSkipped,
    required bool isDark,
  }) {
    final statusColor = isSkipped
        ? AppTheme.warning
        : (isCorrect ? AppTheme.success : AppTheme.danger);
    final statusText =
        isSkipped ? 'SKIPPED' : (isCorrect ? 'CORRECT' : 'INCORRECT');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Question $questionNumber',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (q.topic != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(q.topic!, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              q.question,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Options List
            ...List.generate(q.options.length, (optIdx) {
              final isUserPick = userSelection.contains(optIdx);
              final isRightAnswer = q.correctAnswers.contains(optIdx);
              final exp = q.getExplanation(optIdx);

              Color optBg = Colors.transparent;
              Color optBorder = isDark ? AppTheme.darkBorder : AppTheme.border;
              IconData? optIcon;
              Color iconColor = Colors.grey;

              if (isRightAnswer) {
                optBg = AppTheme.success.withValues(alpha: 0.1);
                optBorder = AppTheme.success;
                optIcon = Icons.check_circle;
                iconColor = AppTheme.success;
              } else if (isUserPick && !isRightAnswer) {
                optBg = AppTheme.danger.withValues(alpha: 0.1);
                optBorder = AppTheme.danger;
                optIcon = Icons.cancel;
                iconColor = AppTheme.danger;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: optBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: optBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (optIcon != null) ...[
                          Icon(optIcon, color: iconColor, size: 18),
                          const SizedBox(width: 10),
                        ] else ...[
                          Text(
                            '${String.fromCharCode(65 + optIdx)}.',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            q.options[optIdx],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: (isRightAnswer || isUserPick)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : (isRightAnswer ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRightAnswer ? '✅ Correct: ' : '❌ Incorrect: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDark ? Colors.white70 : (isRightAnswer ? const Color(0xFF14532D) : const Color(0xFF7F1D1D)),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              exp != null && exp.isNotEmpty
                                  ? exp
                                  : (isRightAnswer
                                      ? 'This is a correct answer for this question.'
                                      : 'This option is incorrect.'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : (isRightAnswer ? const Color(0xFF14532D) : const Color(0xFF7F1D1D)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
