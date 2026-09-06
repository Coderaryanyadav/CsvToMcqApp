import 'question.dart';

class Exam {
  String id;
  String name;
  List<Question> questions;

  Exam({
    required this.id,
    required this.name,
    required this.questions,
  }) {
    reindexQuestions();
  }

  int get nextQuestionNumber => questions.length + 1;

  void addQuestions(List<Question> newQuestions) {
    questions.addAll(newQuestions);
    reindexQuestions();
  }

  void reindexQuestions() {
    for (int i = 0; i < questions.length; i++) {
      final expectedId = 'Q${i + 1}';
      // If id is empty or a UUID or doesn't match Q{i+1}
      if (questions[i].id.isEmpty ||
          questions[i].id.length > 8 ||
          !questions[i].id.startsWith('Q')) {
        questions[i].id = expectedId;
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory Exam.fromJson(Map<String, dynamic> j) {
    final list = (j['questions'] as List? ?? [])
        .map((x) => Question.fromJson(x as Map<String, dynamic>))
        .toList();
    final exam = Exam(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? 'Exam',
      questions: list,
    );
    exam.reindexQuestions();
    return exam;
  }
}

