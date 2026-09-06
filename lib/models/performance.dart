class ExamPerformance {
  final String examId;
  final String examName;
  final DateTime date;
  final int totalQuestions;
  final int correct;
  final int incorrect;
  final int unanswered;
  final int durationSeconds;
  final Map<String, int> timePerQuestion;
  final Map<String, bool> questionResults;
  final List<String> weakTopics;
  final int passingPercentage;
  final Map<String, Map<String, int>> topicPerformance;
  final Map<String, Map<String, int>> difficultyPerformance;

  final String? studentId;
  final String? studentName;

  ExamPerformance({
    this.examId = '',
    this.examName = 'Exam',
    this.studentId,
    this.studentName,
    DateTime? date,
    int? totalQuestions,
    int? total,
    required this.correct,
    int? incorrect,
    this.unanswered = 0,
    this.durationSeconds = 0,
    double? score,
    this.timePerQuestion = const {},
    this.questionResults = const {},
    this.weakTopics = const [],
    this.passingPercentage = 75,
    this.topicPerformance = const {},
    this.difficultyPerformance = const {},
  })  : date = date ?? DateTime.now(),
        totalQuestions = totalQuestions ??
            (total ?? (correct + (incorrect ?? 0) + unanswered)),
        incorrect = incorrect ??
            ((totalQuestions ?? (total ?? correct)) - correct - unanswered);

  double get percentage =>
      totalQuestions > 0 ? (correct / totalQuestions * 100) : 0.0;

  bool get passed => percentage >= passingPercentage;

  Map<String, dynamic> toJson() => {
        'examId': examId,
        'examName': examName,
        'studentId': studentId,
        'studentName': studentName,
        'date': date.toIso8601String(),
        'totalQuestions': totalQuestions,
        'correct': correct,
        'incorrect': incorrect,
        'unanswered': unanswered,
        'durationSeconds': durationSeconds,
        'timePerQuestion': timePerQuestion,
        'questionResults': questionResults,
        'weakTopics': weakTopics,
        'passingPercentage': passingPercentage,
        'topicPerformance': topicPerformance,
        'difficultyPerformance': difficultyPerformance,
      };

  factory ExamPerformance.fromJson(Map<String, dynamic> j) {
    final Map<String, Map<String, int>> topicPerf = {};
    if (j['topicPerformance'] != null && j['topicPerformance'] is Map) {
      (j['topicPerformance'] as Map).forEach((k, v) {
        if (v is Map) {
          topicPerf[k.toString()] = {
            'correct': (v['correct'] as num?)?.toInt() ?? 0,
            'total': (v['total'] as num?)?.toInt() ?? 0,
          };
        }
      });
    }

    final Map<String, Map<String, int>> diffPerf = {};
    if (j['difficultyPerformance'] != null &&
        j['difficultyPerformance'] is Map) {
      (j['difficultyPerformance'] as Map).forEach((k, v) {
        if (v is Map) {
          diffPerf[k.toString()] = {
            'correct': (v['correct'] as num?)?.toInt() ?? 0,
            'total': (v['total'] as num?)?.toInt() ?? 0,
          };
        }
      });
    }

    return ExamPerformance(
      examId: j['examId']?.toString() ?? '',
      examName: j['examName']?.toString() ?? 'Exam',
      studentId: j['studentId']?.toString(),
      studentName: j['studentName']?.toString(),
      date: j['date'] != null
          ? (DateTime.tryParse(j['date'].toString()) ?? DateTime.now())
          : DateTime.now(),
      totalQuestions: (j['totalQuestions'] as num?)?.toInt() ?? 0,
      correct: (j['correct'] as num?)?.toInt() ?? 0,
      incorrect: (j['incorrect'] as num?)?.toInt() ?? 0,
      unanswered: (j['unanswered'] as num?)?.toInt() ?? 0,
      durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
      timePerQuestion: Map<String, int>.from(
        (j['timePerQuestion'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      questionResults: (j['questionResults'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v == true),
          ) ??
          {},
      weakTopics: List<String>.from(j['weakTopics'] ?? []),
      passingPercentage: (j['passingPercentage'] as num?)?.toInt() ?? 75,
      topicPerformance: topicPerf,
      difficultyPerformance: diffPerf,
    );
  }
}

typedef Performance = ExamPerformance;
