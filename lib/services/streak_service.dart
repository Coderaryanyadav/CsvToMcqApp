import '../models/performance.dart';

class StreakInfo {
  final int streakDays;
  final int longestStreak;
  final bool studiedToday;
  final int todayQuestionsCompleted;
  final int dailyGoal;

  const StreakInfo({
    this.streakDays = 0,
    this.longestStreak = 0,
    this.studiedToday = false,
    this.todayQuestionsCompleted = 0,
    this.dailyGoal = 20,
  });

  int get currentStreak => streakDays;
  int get todayQuestionsAnswered => todayQuestionsCompleted;
  bool get isDailyGoalMet => todayQuestionsCompleted >= dailyGoal;
  bool get goalCompleted => isDailyGoalMet;

  double get goalProgress => dailyGoal > 0
      ? (todayQuestionsCompleted / dailyGoal).clamp(0.0, 1.0)
      : 0.0;
}

class StreakService {
  static StreakInfo calculateStreakInfo(
    List<ExamPerformance> performances, {
    int dailyGoal = 20,
  }) {
    if (performances.isEmpty) {
      return StreakInfo(
        streakDays: 0,
        longestStreak: 0,
        studiedToday: false,
        todayQuestionsCompleted: 0,
        dailyGoal: dailyGoal,
      );
    }

    final now = DateTime.now();
    final todayStr = _toDateKey(now);
    final yesterdayStr = _toDateKey(now.subtract(const Duration(days: 1)));

    // Group questions and distinct dates
    final Map<String, int> dailyQuestionCounts = {};
    for (final p in performances) {
      final key = _toDateKey(p.date);
      dailyQuestionCounts[key] =
          (dailyQuestionCounts[key] ?? 0) + p.totalQuestions;
    }

    final int todayQuestions = dailyQuestionCounts[todayStr] ?? 0;
    final bool studiedToday = todayQuestions > 0;

    // Calculate current consecutive days
    int currentStreak = 0;
    DateTime checkDate =
        studiedToday ? now : now.subtract(const Duration(days: 1));

    if (!studiedToday && !dailyQuestionCounts.containsKey(yesterdayStr)) {
      currentStreak = 0;
    } else {
      while (true) {
        final key = _toDateKey(checkDate);
        if (dailyQuestionCounts.containsKey(key) &&
            dailyQuestionCounts[key]! > 0) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // Calculate longest streak in history
    final sortedDates = dailyQuestionCounts.keys
        .where((k) => (dailyQuestionCounts[k] ?? 0) > 0)
        .map((k) => DateTime.parse(k))
        .toList()
      ..sort();

    int longestStreak = currentStreak;
    int tempStreak = 0;
    DateTime? prevDate;

    for (final d in sortedDates) {
      if (prevDate == null) {
        tempStreak = 1;
      } else {
        final diff = d.difference(prevDate).inDays;
        if (diff == 1) {
          tempStreak++;
        } else if (diff > 1) {
          tempStreak = 1;
        }
      }
      if (tempStreak > longestStreak) {
        longestStreak = tempStreak;
      }
      prevDate = d;
    }

    return StreakInfo(
      streakDays: currentStreak,
      longestStreak: longestStreak,
      studiedToday: studiedToday,
      todayQuestionsCompleted: todayQuestions,
      dailyGoal: dailyGoal,
    );
  }

  static String _toDateKey(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
