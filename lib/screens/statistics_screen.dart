import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/performance.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'practice_mode_screen.dart';

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
    'totalQuestions': 0,
    'totalCorrect': 0,
    'totalTimeSeconds': 0,
    'averageTimePerQuestion': 0.0,
    'improvement': 0.0,
    'passRate': 0.0,
  };
  List<ExamPerformance> performances = [];
  List<Exam> allExams = [];
  Map<String, TopicStat> topicStats = {};
  Map<int, DifficultyStat> diffStats = {};
  List<Map<String, dynamic>> trendData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    final exams = await StorageService.loadAllExams();
    final allPerformances = StorageService.loadAllPerformances();
    final stats = AnalyticsService.getOverallStats();
    final topics = AnalyticsService.getTopicBreakdown(exams);
    final diffs = AnalyticsService.getDifficultyBreakdown(exams);
    final trend = AnalyticsService.getChronologicalTrend();

    if (!mounted) return;
    setState(() {
      allExams = exams;
      performances = allPerformances;
      overview = stats;
      topicStats = topics;
      diffStats = diffs;
      trendData = trend;
      loading = false;
    });
  }

  void _practiceTopic(String topic) {
    final matchingQuestions = allExams
        .expand((e) => e.questions)
        .where((q) => q.topic == topic)
        .toList();

    if (matchingQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No questions found for topic "$topic".')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeModeScreen(
          questions: matchingQuestions,
          examName: '$topic - Targeted Practice',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Performance & Analytics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalAttempts = (overview['totalExams'] as num?)?.toInt() ?? 0;
    final avgScore = (overview['averageScore'] as num?)?.toDouble() ?? 0.0;
    final improvement = (overview['improvement'] as num?)?.toDouble() ?? 0.0;
    final totalQ = (overview['totalQuestions'] as num?)?.toInt() ?? 0;
    final passRate = (overview['passRate'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: performances.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.analytics_outlined,
                          size: 56, color: AppTheme.accentBlue),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Exam Activity Yet',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete practice sessions or exam simulations to unlock detailed analytics.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.secondaryText, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. OVERALL STATS HERO
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Average Score',
                              value: '${avgScore.toStringAsFixed(1)}%',
                              subtitle: totalAttempts == 1
                                  ? 'Based on 1 attempt'
                                  : (improvement >= 0
                                      ? '+${improvement.toStringAsFixed(1)}% trend'
                                      : '${improvement.toStringAsFixed(1)}% trend'),
                              icon: Icons.speed,
                              color: AppTheme.accentBlue,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Pass Rate',
                              value: '${passRate.toStringAsFixed(0)}%',
                              subtitle: '$totalAttempts total attempts',
                              icon: Icons.check_circle_outline,
                              color: AppTheme.success,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Questions Answered',
                              value: '$totalQ',
                              subtitle: '${overview['totalCorrect']} correct',
                              icon: Icons.quiz_outlined,
                              color: AppTheme.primaryNavy,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 2. CHRONOLOGICAL TREND
                      _sectionTitle(
                          'Chronological Score History (Oldest → Newest)'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: trendData.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 16),
                                itemBuilder: (context, idx) {
                                  final item = trendData[idx];
                                  final date = item['date'] as DateTime;
                                  final score =
                                      (item['score'] as num).toDouble();
                                  final passed = item['passed'] == true;

                                  return Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: (passed
                                                  ? AppTheme.success
                                                  : AppTheme.danger)
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '#${idx + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: passed
                                                  ? AppTheme.success
                                                  : AppTheme.danger,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['examName']?.toString() ??
                                                  'Exam',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14),
                                            ),
                                            Text(
                                              '${date.toLocal().toString().split('.').first} • ${item['correct']}/${item['total']} correct',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme.secondaryText),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (passed
                                                  ? AppTheme.success
                                                  : AppTheme.danger)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${score.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: passed
                                                ? AppTheme.success
                                                : AppTheme.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 3. TOPIC BREAKDOWN & ACTIONABLE WEAK AREAS
                      _sectionTitle('Topic Accuracy & Weak Areas'),
                      if (topicStats.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No topic breakdown available yet.'),
                          ),
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: topicStats.entries.map((entry) {
                                final topic = entry.key;
                                final stat = entry.value;
                                final acc = stat.accuracy;
                                final isWeak =
                                    stat.totalQuestions >= 2 && acc < 65.0;

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  topic,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14),
                                                ),
                                                if (isWeak) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.danger
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Text(
                                                      'WEAK AREA',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppTheme.danger),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${stat.correctQuestions}/${stat.totalQuestions} questions correct (${acc.toStringAsFixed(0)}%)',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme.secondaryText),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (acc / 100).clamp(0.0, 1.0),
                                            minHeight: 8,
                                            backgroundColor: isDark
                                                ? AppTheme.darkBorder
                                                : AppTheme.border,
                                            valueColor: AlwaysStoppedAnimation(
                                              acc >= 75
                                                  ? AppTheme.success
                                                  : (acc >= 60
                                                      ? AppTheme.warning
                                                      : AppTheme.danger),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon:
                                            const Icon(Icons.school, size: 14),
                                        label: const Text('Practice',
                                            style: TextStyle(fontSize: 12)),
                                        onPressed: () => _practiceTopic(topic),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),

                      // 4. DIFFICULTY BREAKDOWN
                      _sectionTitle('Accuracy by Difficulty Level'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: diffStats.entries.map((entry) {
                              final level = entry.key;
                              final stat = entry.value;
                              final acc = stat.accuracy;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        'Level $level ${level == 1 ? "(Easy)" : level == 5 ? "(Hard)" : ""}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: (acc / 100).clamp(0.0, 1.0),
                                          minHeight: 8,
                                          backgroundColor: isDark
                                              ? AppTheme.darkBorder
                                              : AppTheme.border,
                                          valueColor: AlwaysStoppedAnimation(
                                            acc >= 75
                                                ? AppTheme.success
                                                : (acc >= 60
                                                    ? AppTheme.warning
                                                    : AppTheme.danger),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        stat.totalQuestions > 0
                                            ? '${acc.toStringAsFixed(0)}% (${stat.correctQuestions}/${stat.totalQuestions})'
                                            : 'No data',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.darkSecondaryText
                    : AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppTheme.darkSecondaryText
                    : AppTheme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
