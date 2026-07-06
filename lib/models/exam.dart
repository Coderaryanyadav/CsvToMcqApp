import 'question.dart';

class Exam {
  String id;
  String name;
  List<Question> questions;

  Exam({required this.id, required this.name, required this.questions});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        id: j['id'],
        name: j['name'],
        questions: (j['questions'] as List).map((x) => Question.fromJson(x)).toList(),
      );
}
