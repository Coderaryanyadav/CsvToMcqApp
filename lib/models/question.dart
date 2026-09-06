class Question {
  String id;
  String question;
  String questionType; // 'single' or 'multiple'
  List<String> options;
  Set<int> correctAnswers; // 0..3 indices
  Map<int, String> optionExplanations; // 0..3 -> explanation string
  String? topic;
  int difficulty; // 1 (easy) - 5 (hard)
  List<String> tags;

  Question({
    required this.id,
    required this.question,
    required this.options,
    Set<int>? correctAnswers,
    int? correct,
    this.questionType = 'single',
    Map<int, String>? optionExplanations,
    String? explanation,
    this.topic,
    this.difficulty = 3,
    this.tags = const [],
  })  : correctAnswers = correctAnswers ?? (correct != null ? {correct} : {0}),
        optionExplanations = optionExplanations ??
            (explanation != null && explanation.isNotEmpty
                ? {(correct ?? 0): explanation}
                : {});

  // Legacy convenience getter/setter
  int get correct => correctAnswers.isNotEmpty ? correctAnswers.first : 0;
  set correct(int val) => correctAnswers = {val};

  bool get isMultiple => questionType == 'multiple' || correctAnswers.length > 1;

  String? get explanation {
    if (optionExplanations.containsKey(correct)) {
      return optionExplanations[correct];
    }
    if (optionExplanations.isNotEmpty) {
      return optionExplanations.values.first;
    }
    return null;
  }

  String? getExplanation(int optionIndex) => optionExplanations[optionIndex];

  bool isAnswerCorrect(Set<int> userAnswers) {
    if (userAnswers.isEmpty || userAnswers.length != correctAnswers.length) {
      return false;
    }
    return userAnswers.containsAll(correctAnswers);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'questionType': questionType,
        'options': options,
        'correctAnswers': correctAnswers.toList(),
        'correct': correct, // For backwards compatibility
        'optionExplanations':
            optionExplanations.map((k, v) => MapEntry(k.toString(), v)),
        'explanation': explanation, // For backwards compatibility
        'topic': topic,
        'difficulty': difficulty,
        'tags': tags,
      };

  factory Question.fromJson(Map<String, dynamic> j) {
    Set<int> answers = {};
    if (j['correctAnswers'] != null && j['correctAnswers'] is List) {
      answers = (j['correctAnswers'] as List)
          .map((e) => (e as num).toInt())
          .toSet();
    } else if (j['correct'] != null) {
      answers = {(j['correct'] as num).toInt()};
    } else {
      answers = {0};
    }

    String type = j['questionType']?.toString().toLowerCase() ?? 'single';
    if (answers.length > 1) {
      type = 'multiple';
    }

    final Map<int, String> explanations = {};
    if (j['optionExplanations'] != null && j['optionExplanations'] is Map) {
      (j['optionExplanations'] as Map).forEach((k, v) {
        final parsedKey = int.tryParse(k.toString());
        if (parsedKey != null && v != null && v.toString().isNotEmpty) {
          explanations[parsedKey] = v.toString();
        }
      });
    }

    // Check individual explanation fields if not found in map
    const optKeys = ['explanation_a', 'explanation_b', 'explanation_c', 'explanation_d'];
    for (int i = 0; i < optKeys.length; i++) {
      final key = optKeys[i];
      if (j[key] != null && j[key].toString().isNotEmpty && !explanations.containsKey(i)) {
        explanations[i] = j[key].toString();
      }
    }

    // Fallback single explanation
    if (explanations.isEmpty && j['explanation'] != null && j['explanation'].toString().isNotEmpty) {
      final defaultKey = answers.isNotEmpty ? answers.first : 0;
      explanations[defaultKey] = j['explanation'].toString();
    }

    return Question(
      id: j['id']?.toString() ?? 'Q1',
      question: j['question']?.toString() ?? '',
      options: j['options'] != null ? List<String>.from(j['options']) : [],
      correctAnswers: answers,
      questionType: type,
      optionExplanations: explanations,
      topic: j['topic']?.toString(),
      difficulty: j['difficulty'] != null ? (j['difficulty'] as num).toInt() : 3,
      tags: j['tags'] != null ? List<String>.from(j['tags']) : [],
    );
  }
}
