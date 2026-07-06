import 'dart:io';

import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../models/performance.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool loading = true;
  Map<String, dynamic> overview = const {
    'totalExams': 0,
    'averageScore': 0.0,
    'totalCorrect': 0,
    'improvement': 0.0,
  };
  List<ExamPerformance> performances = [];
  List<_ExamSummary> examSummaries = [];
  List<_TopicInsight> topicInsights = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
    });
    try {
      await StorageService.init();
    } catch (_) {}
    final allPerformances = StorageService.loadAllPerformances();
    final stats = AnalyticsService.getOverallStats();
    final questionsById = await _buildQuestionLookup();
    final insights = _buildTopicInsights(allPerformances, questionsById);
    final summaries = _buildExamSummaries(allPerformances);
    if (!mounted) return;
    setState(() {
      overview = stats;
      performances = allPerformances;
      topicInsights = insights;
      examSummaries = summaries;
      loading = false;
    });
  }

  Future<Map<String, Question>> _buildQuestionLookup() async {
    final lookup = <String, Question>{};
    final files = StorageService.listExamFiles();
    for (final entity in files) {
      final filename = entity.path.split(Platform.pathSeparator).last;
      try {
        final json = await StorageService.readExamFile(filename);
        final exam = Exam.fromJson(json);
        for (final question in exam.questions) {
          lookup[question.id] = question;
        }
      } catch (_) {
        // ignore unreadable exam files during analytics
      }
    }
    return lookup;
  }

  List<_TopicInsight> _buildTopicInsights(
    List<ExamPerformance> allPerformances,
    Map<String, Question> questions,
  ) {
    final Map<String, _TopicCounter> counters = {};
    for (final perf in allPerformances) {
      perf.questionResults.forEach((questionId, correct) {
        final question = questions[questionId];
        final topic =
            (question?.topic?.trim().isNotEmpty ?? false) ? question!.topic!.trim() : 'General';
        counters.putIfAbsent(topic, () => _TopicCounter()).register(correct);
      });
    }
    final insights = counters.entries
        .map(
          (entry) => _TopicInsight(
            topic: entry.key,
            accuracy: entry.value.accuracy,
            attempts: entry.value.total,
          ),
        )
        .toList();
    insights.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return insights;
  }

  List<_ExamSummary> _buildExamSummaries(List<ExamPerformance> allPerformances) {
    final Map<String, _ExamAggregate> aggregates = {};
    for (final perf in allPerformances) {
      aggregates.putIfAbsent(
        perf.examId,
        () => _ExamAggregate(examId: perf.examId, examName: perf.examName),
      ).record(perf);
    }
    final summaries = aggregates.values
        .map(
          (agg) => _ExamSummary(
            examId: agg.examId,
            examName: agg.examName,
            attempts: agg.attempts,
            averageScore: agg.totalScore / agg.attempts,
            bestScore: agg.bestScore,
            lastTaken: agg.lastTaken,
          ),
        )
        .toList();
    summaries.sort((a, b) => b.lastTaken.compareTo(a.lastTaken));
    return summaries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics & Analytics'),
        backgroundColor: Colors.deepPurple,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Overall Performance',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(
                                label: 'Total Exams',
                                value: '${overview['totalExams']}',
                                icon: Icons.quiz,
                                color: Colors.blue,
                              ),
                              _StatItem(
                                label: 'Avg Score',
                                value:
                                    '${(overview['averageScore'] as double).toStringAsFixed(1)}%',
                                icon: Icons.trending_up,
                                color: Colors.green,
                              ),
                              _StatItem(
                                label: 'Correct',
                                value: '${overview['totalCorrect']}',
                                icon: Icons.check_circle,
                                color: Colors.teal,
                              ),
                            ],
                          ),
                          if ((overview['improvement'] as double) != 0.0) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (overview['improvement'] as double) > 0
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    (overview['improvement'] as double) > 0
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: (overview['improvement'] as double) > 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(overview['improvement'] as double) > 0 ? '+' : ''}${(overview['improvement'] as double).toStringAsFixed(1)}% improvement',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: (overview['improvement'] as double) > 0
                                          ? Colors.green.shade900
                                          : Colors.red.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (topicInsights.isNotEmpty) ...[
                    const Text(
                      'Weak Topics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topicInsights
                          .take(8)
                          .map(
                            (insight) => Chip(
                              avatar: Icon(
                                insight.accuracy >= 0.75
                                    ? Icons.check_circle
                                    : insight.accuracy >= 0.5
                                        ? Icons.trending_down
                                        : Icons.warning,
                                size: 16,
                                color: insight.accuracy >= 0.75
                                    ? Colors.green
                                    : insight.accuracy >= 0.5
                                        ? Colors.amber
                                        : Colors.red,
                              ),
                              label: Text(
                                '${insight.topic} • ${(insight.accuracy * 100).toStringAsFixed(0)}%',
                              ),
                              backgroundColor: insight.accuracy >= 0.75
                                  ? Colors.green.shade50
                                  : insight.accuracy >= 0.5
                                      ? Colors.amber.shade50
                                      : Colors.red.shade50,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (examSummaries.isNotEmpty) ...[
                    const Text(
                      'Exam Health',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...examSummaries.take(5).map(
                          (summary) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    summary.examName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MiniStat(
                                          label: 'Avg',
                                          value: '${summary.averageScore.toStringAsFixed(1)}%',
                                        ),
                                      ),
                                      Expanded(
                                        child: _MiniStat(
                                          label: 'Best',
                                          value: '${summary.bestScore.toStringAsFixed(1)}%',
                                        ),
                                      ),
                                      Expanded(
                                        child: _MiniStat(
                                          label: 'Attempts',
                                          value: '${summary.attempts}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Last taken: ${summary.lastTaken.day}/${summary.lastTaken.month}/${summary.lastTaken.year}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Recent Exam Results',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (performances.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No exam results yet',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Complete some exams to see your statistics here',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...performances.take(20).map(
                          (perf) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: perf.percentage >= 70
                                    ? Colors.green.shade100
                                    : perf.percentage >= 50
                                        ? Colors.orange.shade100
                                        : Colors.red.shade100,
                                child: Icon(
                                  perf.percentage >= 70
                                      ? Icons.check_circle
                                      : perf.percentage >= 50
                                          ? Icons.warning
                                          : Icons.error,
                                  color: perf.percentage >= 70
                                      ? Colors.green
                                      : perf.percentage >= 50
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                              title: Text(
                                perf.examName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${perf.date.day}/${perf.date.month}/${perf.date.year} • ${(perf.durationSeconds / 60).toStringAsFixed(0)} min',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${perf.percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: perf.percentage >= 70
                                          ? Colors.green
                                          : perf.percentage >= 50
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                  Text(
                                    '${perf.correct}/${perf.totalQuestions}',
                                    style:
                                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }
}

class _TopicInsight {
  final String topic;
  final double accuracy;
  final int attempts;

  const _TopicInsight({
    required this.topic,
    required this.accuracy,
    required this.attempts,
  });
}

class _TopicCounter {
  int total = 0;
  int correct = 0;

  void register(bool isCorrect) {
    total += 1;
    if (isCorrect) correct += 1;
  }

  double get accuracy => total == 0 ? 0 : correct / total;
}

class _ExamSummary {
  final String examId;
  final String examName;
  final int attempts;
  final double averageScore;
  final double bestScore;
  final DateTime lastTaken;

  const _ExamSummary({
    required this.examId,
    required this.examName,
    required this.attempts,
    required this.averageScore,
    required this.bestScore,
    required this.lastTaken,
  });
}

class _ExamAggregate {
  final String examId;
  final String examName;
  int attempts = 0;
  double totalScore = 0;
  double bestScore = 0;
  DateTime lastTaken = DateTime.fromMillisecondsSinceEpoch(0);

  _ExamAggregate({required this.examId, required this.examName});

  void record(ExamPerformance perf) {
    attempts += 1;
    totalScore += perf.percentage;
    if (perf.percentage > bestScore) bestScore = perf.percentage;
    if (perf.date.isAfter(lastTaken)) lastTaken = perf.date;
  }
}
