import '../models/exam.dart';
import '../models/performance.dart';

class TopicStat {
  final String topic;
  final int totalQuestions;
  final int correctQuestions;

  const TopicStat({
    required this.topic,
    required this.totalQuestions,
    required this.correctQuestions,
  });

  double get accuracy =>
      totalQuestions > 0 ? (correctQuestions / totalQuestions * 100) : 0.0;
}

class DifficultyStat {
  final int difficulty;
  final int totalQuestions;
  final int correctQuestions;

  const DifficultyStat({
    required this.difficulty,
    required this.totalQuestions,
    required this.correctQuestions,
  });

  double get accuracy =>
      totalQuestions > 0 ? (correctQuestions / totalQuestions * 100) : 0.0;
}

class AnalyticsSummary {
  final int totalAttempts;
  final double overallAccuracy;
  final double improvement;
  final int totalQuestions;
  final int totalCorrect;
  final int totalTimeSeconds;
  final double averageTimePerQuestion;
  final double passRate;
  final List<double> scoreTrend;
  final Map<String, double> topicAccuracy;
  final Map<String, double> difficultyAccuracy;
  final List<String> weakAreas;

  const AnalyticsSummary({
    required this.totalAttempts,
    required this.overallAccuracy,
    required this.improvement,
    this.totalQuestions = 0,
    this.totalCorrect = 0,
    this.totalTimeSeconds = 0,
    this.averageTimePerQuestion = 0.0,
    this.passRate = 0.0,
    this.scoreTrend = const [],
    this.topicAccuracy = const {},
    this.difficultyAccuracy = const {},
    this.weakAreas = const [],
  });
}

class AnalyticsService {
  static AnalyticsSummary calculateSummary(List<ExamPerformance> performances) {
    if (performances.isEmpty) {
      return const AnalyticsSummary(
        totalAttempts: 0,
        overallAccuracy: 0.0,
        improvement: 0.0,
        totalQuestions: 0,
        totalCorrect: 0,
        totalTimeSeconds: 0,
        averageTimePerQuestion: 0.0,
        passRate: 0.0,
        scoreTrend: [],
        topicAccuracy: {},
        difficultyAccuracy: {},
        weakAreas: [],
      );
    }

    // Sort strictly chronological: oldest -> newest
    final chronological = List<ExamPerformance>.from(performances)
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalExams = chronological.length;
    final totalQuestions =
        chronological.fold(0, (sum, p) => sum + p.totalQuestions);
    final totalCorrect = chronological.fold(0, (sum, p) => sum + p.correct);
    final totalTimeSeconds =
        chronological.fold(0, (sum, p) => sum + p.durationSeconds);
    final passedExams = chronological.where((p) => p.passed).length;
    final passRate = totalExams > 0 ? (passedExams / totalExams * 100) : 0.0;

    final overallAccuracy =
        totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0.0;
    final averageTimePerQuestion =
        totalQuestions > 0 ? (totalTimeSeconds / totalQuestions) : 0.0;

    // Chronological improvement calculation: sort oldest -> newest
    double improvement = 0.0;
    if (chronological.length >= 2) {
      final mid = chronological.length ~/ 2;
      final earlier = chronological.sublist(0, mid);
      final recent = chronological.sublist(mid);

      final earlierAvg =
          earlier.fold(0.0, (sum, p) => sum + p.percentage) / earlier.length;
      final recentAvg =
          recent.fold(0.0, (sum, p) => sum + p.percentage) / recent.length;

      improvement = recentAvg - earlierAvg;
    }

    final scoreTrend = chronological.map((p) => p.percentage).toList();

    // Topic performance aggregation (including historical snapshot awareness)
    final topicTotals = <String, int>{};
    final topicCorrects = <String, int>{};
    final diffTotals = <String, int>{};
    final diffCorrects = <String, int>{};

    for (final p in chronological) {
      p.topicPerformance.forEach((topic, counts) {
        topicTotals[topic] = (topicTotals[topic] ?? 0) + (counts['total'] ?? 0);
        topicCorrects[topic] =
            (topicCorrects[topic] ?? 0) + (counts['correct'] ?? 0);
      });

      p.difficultyPerformance.forEach((diff, counts) {
        diffTotals[diff] = (diffTotals[diff] ?? 0) + (counts['total'] ?? 0);
        diffCorrects[diff] =
            (diffCorrects[diff] ?? 0) + (counts['correct'] ?? 0);
      });
    }

    final topicAccuracy = <String, double>{};
    final weakAreas = <String>[];
    topicTotals.forEach((topic, total) {
      if (total > 0) {
        final correct = topicCorrects[topic] ?? 0;
        final acc = (correct / total) * 100;
        topicAccuracy[topic] = acc;
        if (acc < 70.0) {
          weakAreas.add(topic);
        }
      }
    });

    final difficultyAccuracy = <String, double>{};
    diffTotals.forEach((diff, total) {
      if (total > 0) {
        final correct = diffCorrects[diff] ?? 0;
        difficultyAccuracy[diff] = (correct / total) * 100;
      }
    });

    return AnalyticsSummary(
      totalAttempts: totalExams,
      overallAccuracy: double.parse(overallAccuracy.toStringAsFixed(1)),
      improvement: double.parse(improvement.toStringAsFixed(1)),
      totalQuestions: totalQuestions,
      totalCorrect: totalCorrect,
      totalTimeSeconds: totalTimeSeconds,
      averageTimePerQuestion: averageTimePerQuestion,
      passRate: passRate,
      scoreTrend: scoreTrend,
      topicAccuracy: topicAccuracy,
      difficultyAccuracy: difficultyAccuracy,
      weakAreas: weakAreas,
    );
  }

  static Map<String, dynamic> getOverallStats(
      List<ExamPerformance> performances) {
    final summary = calculateSummary(performances);

    return {
      'totalExams': summary.totalAttempts,
      'averageScore': summary.overallAccuracy,
      'totalQuestions': summary.totalQuestions,
      'totalCorrect': summary.totalCorrect,
      'totalTimeSeconds': summary.totalTimeSeconds,
      'averageTimePerQuestion': summary.averageTimePerQuestion,
      'improvement': summary.improvement,
      'passRate': summary.passRate,
    };
  }

  static List<Map<String, dynamic>> getChronologicalTrend(
      List<ExamPerformance> performances,
      {String? examId}) {
    List<ExamPerformance> filtered = examId != null
        ? performances.where((p) => p.examId == examId).toList()
        : List<ExamPerformance>.from(performances);

    // Sort strictly chronological: oldest -> newest
    final chronological = List<ExamPerformance>.from(filtered)
      ..sort((a, b) => a.date.compareTo(b.date));

    return chronological.map((p) {
      return {
        'date': p.date,
        'score': p.percentage,
        'correct': p.correct,
        'total': p.totalQuestions,
        'examName': p.examName,
        'examId': p.examId,
        'passed': p.passed,
        'durationSeconds': p.durationSeconds,
      };
    }).toList();
  }

  static Map<String, TopicStat> getTopicBreakdown(
    List<ExamPerformance> performances, [
    List<Exam>? allExams,
  ]) {
    final questionTopicMap = <String, String>{};

    if (allExams != null) {
      for (final exam in allExams) {
        for (final q in exam.questions) {
          if (q.topic != null && q.topic!.trim().isNotEmpty) {
            questionTopicMap[q.id] = q.topic!.trim();
          }
        }
      }
    }

    final topicTotals = <String, int>{};
    final topicCorrects = <String, int>{};

    for (final perf in performances) {
      if (perf.topicPerformance.isNotEmpty) {
        perf.topicPerformance.forEach((topic, counts) {
          topicTotals[topic] =
              (topicTotals[topic] ?? 0) + (counts['total'] ?? 0);
          topicCorrects[topic] =
              (topicCorrects[topic] ?? 0) + (counts['correct'] ?? 0);
        });
      } else {
        for (final entry in perf.questionResults.entries) {
          final snapshot = perf.questionSnapshots[entry.key];
          final topic = snapshot?['topic']?.toString() ??
              questionTopicMap[entry.key] ??
              'General';
          topicTotals[topic] = (topicTotals[topic] ?? 0) + 1;
          if (entry.value) {
            topicCorrects[topic] = (topicCorrects[topic] ?? 0) + 1;
          }
        }
      }
    }

    final result = <String, TopicStat>{};
    topicTotals.forEach((topic, total) {
      final correct = topicCorrects[topic] ?? 0;
      result[topic] = TopicStat(
        topic: topic,
        totalQuestions: total,
        correctQuestions: correct,
      );
    });

    return result;
  }

  static List<String> identifyWeakTopics(
    List<ExamPerformance> performances, [
    List<Exam>? allExams,
  ]) {
    final breakdown = getTopicBreakdown(performances, allExams);
    final weak = <String>[];

    breakdown.forEach((topic, stat) {
      if (stat.totalQuestions >= 2 && stat.accuracy < 65.0) {
        weak.add(topic);
      }
    });

    return weak;
  }

  static Map<int, DifficultyStat> getDifficultyBreakdown(
    List<ExamPerformance> performances, [
    List<Exam>? allExams,
  ]) {
    final questionDiffMap = <String, int>{};

    if (allExams != null) {
      for (final exam in allExams) {
        for (final q in exam.questions) {
          questionDiffMap[q.id] = q.difficulty;
        }
      }
    }

    final diffTotals = <int, int>{};
    final diffCorrects = <int, int>{};

    for (final perf in performances) {
      if (perf.difficultyPerformance.isNotEmpty) {
        perf.difficultyPerformance.forEach((diffStr, counts) {
          final d = int.tryParse(diffStr) ?? 3;
          diffTotals[d] = (diffTotals[d] ?? 0) + (counts['total'] ?? 0);
          diffCorrects[d] = (diffCorrects[d] ?? 0) + (counts['correct'] ?? 0);
        });
      } else {
        for (final entry in perf.questionResults.entries) {
          final snapshot = perf.questionSnapshots[entry.key];
          final diff = (snapshot?['difficulty'] as num?)?.toInt() ??
              questionDiffMap[entry.key] ??
              3;
          diffTotals[diff] = (diffTotals[diff] ?? 0) + 1;
          if (entry.value) {
            diffCorrects[diff] = (diffCorrects[diff] ?? 0) + 1;
          }
        }
      }
    }

    final result = <int, DifficultyStat>{};
    for (int d = 1; d <= 5; d++) {
      final total = diffTotals[d] ?? 0;
      final correct = diffCorrects[d] ?? 0;
      result[d] = DifficultyStat(
        difficulty: d,
        totalQuestions: total,
        correctQuestions: correct,
      );
    }

    return result;
  }
}
