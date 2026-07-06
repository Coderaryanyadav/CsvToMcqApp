class Question {
  String id;
  String question;
  List<String> options;
  int correct; // index 0..3
  String? explanation;
  String? topic;
  int difficulty; // 1 (easy) - 5 (hard)
  List<String> tags;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correct,
    this.explanation,
    this.topic,
    this.difficulty = 3,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'options': options,
        'correct': correct,
        'explanation': explanation,
        'topic': topic,
        'difficulty': difficulty,
        'tags': tags,
      };

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'],
        question: j['question'],
        options: List<String>.from(j['options']),
        correct: j['correct'],
        explanation: j['explanation'],
        topic: j['topic'],
        difficulty: j['difficulty'] ?? 3,
        tags: j['tags'] != null ? List<String>.from(j['tags']) : [],
      );
}
