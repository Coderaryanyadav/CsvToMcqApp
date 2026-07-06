class ExamPerformance {
  String examId;
  String examName;
  DateTime date;
  int totalQuestions;
  int correct;
  int incorrect;
  int unanswered;
  int durationSeconds;
  Map<String, int> timePerQuestion;
  Map<String, bool> questionResults;
  List<String> weakTopics;

  ExamPerformance({
    required this.examId,
    required this.examName,
    required this.date,
    required this.totalQuestions,
    required this.correct,
    required this.incorrect,
    required this.unanswered,
    required this.durationSeconds,
    this.timePerQuestion = const {},
    this.questionResults = const {},
    this.weakTopics = const [],
  });

  double get percentage =>
      totalQuestions > 0 ? (correct / totalQuestions * 100) : 0.0;

  Map<String, dynamic> toJson() => {
        'examId': examId,
        'examName': examName,
        'date': date.toIso8601String(),
        'totalQuestions': totalQuestions,
        'correct': correct,
        'incorrect': incorrect,
        'unanswered': unanswered,
        'durationSeconds': durationSeconds,
        'timePerQuestion': timePerQuestion,
        'questionResults': questionResults.map((k, v) => MapEntry(k, v)),
        'weakTopics': weakTopics,
      };

  factory ExamPerformance.fromJson(Map<String, dynamic> j) => ExamPerformance(
        examId: j['examId'],
        examName: j['examName'],
        date: DateTime.parse(j['date']),
        totalQuestions: j['totalQuestions'],
        correct: j['correct'],
        incorrect: j['incorrect'],
        unanswered: j['unanswered'],
        durationSeconds: j['durationSeconds'],
        timePerQuestion: Map<String, int>.from(j['timePerQuestion'] ?? {}),
        questionResults: (j['questionResults'] ?? {}).map(
          (k, v) => MapEntry(k as String, v as bool),
        ),
        weakTopics: List<String>.from(j['weakTopics'] ?? []),
      );
}
