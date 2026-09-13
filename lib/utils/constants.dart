class AppConstants {
  // Business Rules
  static const int defaultExamDurationMinutes = 30;
  static const int defaultPassingPercentage = 75;
  static const int defaultDailyGoal = 20;
  static const int defaultQuestionDifficulty = 3;
  static const double weakTopicAccuracyThreshold = 65.0;
  static const int minQuestionsForWeakTopic = 2;
  static const int minOptionsPerQuestion = 2;
  static const int standardOptionsPerQuestion = 4;
  static const int minDifficulty = 1;
  static const int maxDifficulty = 5;

  // Question & Exam limits
  static const int maxQuestionsPerExam = 1000;
  static const int defaultPresetQuestionsCount = 20;

  // Session & Autosave
  static const int autosaveIntervalSeconds = 10;
}
