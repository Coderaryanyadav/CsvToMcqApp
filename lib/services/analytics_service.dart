import '../models/question.dart';
import 'storage_service.dart';

class AnalyticsService {
  static Map<String, dynamic> getOverallStats() {
    final performances = StorageService.loadAllPerformances();
    if (performances.isEmpty) {
      return {
        'totalExams': 0,
        'averageScore': 0.0,
        'totalQuestions': 0,
        'totalCorrect': 0,
        'improvement': 0.0,
      };
    }

    final totalExams = performances.length;
    final totalQuestions =
        performances.fold(0, (sum, p) => sum + p.totalQuestions);
    final totalCorrect = performances.fold(0, (sum, p) => sum + p.correct);
    final averageScore =
        totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0.0;

    double improvement = 0.0;
    if (performances.length >= 2) {
      final mid = performances.length ~/ 2;
      final earlier = performances.sublist(0, mid);
      final recent = performances.sublist(mid);
      final recentAvg =
          recent.fold(0.0, (sum, p) => sum + p.percentage) / recent.length;
      final earlierAvg =
          earlier.fold(0.0, (sum, p) => sum + p.percentage) / earlier.length;
      improvement = recentAvg - earlierAvg;
    }

    return {
      'totalExams': totalExams,
      'averageScore': averageScore,
      'totalQuestions': totalQuestions,
      'totalCorrect': totalCorrect,
      'improvement': improvement,
    };
  }

  static List<String> identifyWeakTopics(String examId) {
    final performances = StorageService.getPerformancesForExam(examId);
    if (performances.isEmpty) return [];

    final topicScores = <String, List<bool>>{};
    for (var perf in performances) {
      for (var entry in perf.questionResults.entries) {
        const topic = 'General'; // placeholder until questions have topics
        topicScores.putIfAbsent(topic, () => []).add(entry.value);
      }
    }

    final weakTopics = <String>[];
    topicScores.forEach((topic, scores) {
      final accuracy = scores.where((s) => s).length / scores.length;
      if (accuracy < 0.6) {
        weakTopics.add(topic);
      }
    });
    return weakTopics;
  }

  static List<Map<String, dynamic>> getPerformanceTrend(String examId) {
    final performances = StorageService.getPerformancesForExam(examId);
    return performances
        .map((p) => {
              'date': p.date,
              'score': p.percentage,
              'correct': p.correct,
              'total': p.totalQuestions,
            })
        .toList();
  }

  static List<String> recommendQuestions(
      String examId, List<Question> allQuestions) {
    final performances = StorageService.getPerformancesForExam(examId);
    if (performances.isEmpty) return [];

    final questionAccuracy = <String, List<bool>>{};
    for (var perf in performances) {
      for (var entry in perf.questionResults.entries) {
        questionAccuracy.putIfAbsent(entry.key, () => []).add(entry.value);
      }
    }

    final recommendations = <String>[];
    questionAccuracy.forEach((qId, results) {
      final accuracy = results.where((r) => r).length / results.length;
      if (accuracy < 0.7) {
        recommendations.add(qId);
      }
    });
    return recommendations;
  }
}
