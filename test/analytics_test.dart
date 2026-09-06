import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/performance.dart';
import 'package:csv_to_mcq_app/services/analytics_service.dart';

void main() {
  group('AnalyticsService Chronological Calculations', () {
    test('Improvement calculation uses chronological order (oldest to newest)',
        () {
      // Storage stores newest first (e.g. attempt on day 3, day 2, day 1)
      final performances = [
        Performance(
          examName: 'Math',
          score: 90.0,
          correct: 9,
          total: 10,
          date: DateTime(2026, 1, 3), // Most recent (90%)
        ),
        Performance(
          examName: 'Math',
          score: 70.0,
          correct: 7,
          total: 10,
          date: DateTime(2026, 1, 2), // Middle (70%)
        ),
        Performance(
          examName: 'Math',
          score: 50.0,
          correct: 5,
          total: 10,
          date: DateTime(2026, 1, 1), // Earliest (50%)
        ),
      ];

      final summary = AnalyticsService.calculateSummary(performances);

      // Total attempts = 3, average = (90 + 70 + 50) / 3 = 70.0
      expect(summary.totalAttempts, 3);
      expect(summary.overallAccuracy, 70.0);

      // Earlier half average: Day 1 (50%)
      // Recent half average: Day 2 (70%) & Day 3 (90%) -> avg = 80%
      // Improvement should be POSITIVE (80 - 50 = +30)
      expect(summary.improvement, greaterThan(0));
      expect(summary.improvement, 30.0);
    });

    test('Declining performance produces negative improvement', () {
      final performances = [
        Performance(
          examName: 'Physics',
          score: 40.0,
          correct: 4,
          total: 10,
          date: DateTime(2026, 2, 3), // Most recent (40%)
        ),
        Performance(
          examName: 'Physics',
          score: 60.0,
          correct: 6,
          total: 10,
          date: DateTime(2026, 2, 2), // Middle (60%)
        ),
        Performance(
          examName: 'Physics',
          score: 90.0,
          correct: 9,
          total: 10,
          date: DateTime(2026, 2, 1), // Earliest (90%)
        ),
      ];

      final summary = AnalyticsService.calculateSummary(performances);

      // Earlier: Day 1 (90%)
      // Recent: Day 2 (60%) + Day 3 (40%) = 50%
      // Improvement: 50 - 90 = -40
      expect(summary.improvement, lessThan(0));
      expect(summary.improvement, -40.0);
    });

    test('Empty performances returns 0 and empty stats with no fabricated data',
        () {
      final summary = AnalyticsService.calculateSummary([]);

      expect(summary.totalAttempts, 0);
      expect(summary.overallAccuracy, 0.0);
      expect(summary.improvement, 0.0);
      expect(summary.scoreTrend, isEmpty);
      expect(summary.topicAccuracy, isEmpty);
      expect(summary.weakAreas, isEmpty);
    });

    test(
        'Topic and difficulty breakdowns accurately compute accuracy and weak areas',
        () {
      final performances = [
        Performance(
          examName: 'DevOps Exam',
          score: 80.0,
          correct: 8,
          total: 10,
          date: DateTime(2026, 3, 1),
          topicPerformance: {
            'Networking': {'correct': 2, 'total': 5}, // 40% (Weak)
            'Security': {'correct': 4, 'total': 5}, // 80%
            'Storage': {'correct': 5, 'total': 5}, // 100%
          },
          difficultyPerformance: {
            '1': {'correct': 5, 'total': 5}, // Easy: 100%
            '3': {'correct': 3, 'total': 5}, // Medium: 60%
          },
        ),
      ];

      final summary = AnalyticsService.calculateSummary(performances);

      expect(summary.topicAccuracy['Networking'], 40.0);
      expect(summary.topicAccuracy['Security'], 80.0);
      expect(summary.topicAccuracy['Storage'], 100.0);

      expect(summary.difficultyAccuracy['1'], 100.0);
      expect(summary.difficultyAccuracy['3'], 60.0);

      // Networking (< 70%) should be identified as a weak area
      expect(summary.weakAreas, contains('Networking'));
      expect(summary.weakAreas, isNot(contains('Storage')));
    });
  });
}
