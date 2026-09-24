import 'package:uuid/uuid.dart';

const Object _unset = Object();

class Question {
  final String id;
  String question;
  String questionType; // 'single' or 'multiple'
  List<String> options;
  Set<int> correctAnswers; // 0..3 indices
  Map<int, String> optionExplanations; // 0..3 -> explanation string
  String? topic;
  String? chapter;
  int difficulty; // 1 (easy) - 5 (hard)
  List<String> tags;
  int? displayNumber;

  Question({
    String? id,
    required this.question,
    required this.options,
    Set<int>? correctAnswers,
    int? correct,
    this.questionType = 'single',
    Map<int, String>? optionExplanations,
    String? explanation,
    this.topic,
    this.chapter,
    this.difficulty = 3,
    this.tags = const [],
    this.displayNumber,
  })  : id = (id != null && id.isNotEmpty) ? id : const Uuid().v4(),
        correctAnswers = correctAnswers ??
            (correct != null && correct >= 0 ? {correct} : <int>{}),
        optionExplanations = optionExplanations ??
            (explanation != null && explanation.isNotEmpty
                ? {
                    (correct ??
                        (correctAnswers?.isNotEmpty == true
                            ? correctAnswers!.first
                            : 0)): explanation
                  }
                : {});

  // Display label for UI (e.g., "Q1" or "Question 1")
  String get displayId {
    if (displayNumber != null) return 'Q$displayNumber';
    if (id.startsWith('Q') && id.length <= 6) return id;
    if (id.length <= 6) return id;
    return 'Q';
  }

  // Legacy convenience getter/setter
  int get correct => correctAnswers.isNotEmpty ? correctAnswers.first : -1;
  set correct(int val) => correctAnswers = val >= 0 ? {val} : <int>{};

  bool get isMultiple =>
      questionType == 'multiple' || correctAnswers.length > 1;

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

  Question copyWith({
    String? id,
    String? question,
    String? questionType,
    List<String>? options,
    Set<int>? correctAnswers,
    Map<int, String>? optionExplanations,
    Object? topic = _unset,
    Object? chapter = _unset,
    int? difficulty,
    List<String>? tags,
    Object? displayNumber = _unset,
  }) {
    return Question(
      id: id ?? this.id,
      question: question ?? this.question,
      questionType: questionType ?? this.questionType,
      options: options ?? List.from(this.options),
      correctAnswers: correctAnswers ?? Set.from(this.correctAnswers),
      optionExplanations:
          optionExplanations ?? Map.from(this.optionExplanations),
      topic: identical(topic, _unset) ? this.topic : topic as String?,
      chapter: identical(chapter, _unset) ? this.chapter : chapter as String?,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? List.from(this.tags),
      displayNumber: identical(displayNumber, _unset)
          ? this.displayNumber
          : displayNumber as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'questionType': questionType,
        'options': options,
        'correctAnswers': correctAnswers.toList(),
        'correct': correct, // Backwards compatibility
        'optionExplanations':
            optionExplanations.map((k, v) => MapEntry(k.toString(), v)),
        'explanation': explanation, // Backwards compatibility
        'topic': topic,
        'chapter': chapter,
        'difficulty': difficulty,
        'tags': tags,
        'displayNumber': displayNumber,
      };

  factory Question.fromJson(Map<String, dynamic> j) {
    Set<int> answers = {};
    if (j['correctAnswers'] != null && j['correctAnswers'] is List) {
      answers =
          (j['correctAnswers'] as List).map((e) => (e as num).toInt()).toSet();
    } else if (j['correct'] != null) {
      final c = (j['correct'] as num).toInt();
      if (c >= 0) answers = {c};
    } else {
      answers = {};
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
    const optKeys = [
      'explanation_a',
      'explanation_b',
      'explanation_c',
      'explanation_d'
    ];
    for (int i = 0; i < optKeys.length; i++) {
      final key = optKeys[i];
      if (j[key] != null &&
          j[key].toString().isNotEmpty &&
          !explanations.containsKey(i)) {
        explanations[i] = j[key].toString();
      }
    }

    // Fallback single explanation
    if (explanations.isEmpty &&
        j['explanation'] != null &&
        j['explanation'].toString().isNotEmpty) {
      final defaultKey = answers.isNotEmpty ? answers.first : 0;
      explanations[defaultKey] = j['explanation'].toString();
    }

    int? dispNum;
    if (j['displayNumber'] != null) {
      dispNum = (j['displayNumber'] as num).toInt();
    } else if (j['id'] != null && j['id'].toString().startsWith('Q')) {
      dispNum =
          int.tryParse(j['id'].toString().replaceAll(RegExp(r'[^0-9]'), ''));
    }

    return Question(
      id: j['id']?.toString(),
      question: j['question']?.toString() ?? '',
      options: j['options'] != null ? List<String>.from(j['options']) : [],
      correctAnswers: answers,
      questionType: type,
      optionExplanations: explanations,
      topic: j['topic']?.toString(),
      chapter: j['chapter']?.toString(),
      difficulty:
          j['difficulty'] != null ? (j['difficulty'] as num).toInt() : 3,
      tags: j['tags'] != null ? List<String>.from(j['tags']) : [],
      displayNumber: dispNum,
    );
  }
}
