import 'package:uuid/uuid.dart';
import 'question.dart';

const Object _unsetDuration = Object();

class Exam {
  final String id;
  String name;
  String description;
  String category;
  String provider;
  String code;
  List<Question> questions;
  int passingPercentage; // e.g. 75
  int? defaultDuration; // In minutes, null or 0 for untimed
  DateTime createdAt;
  DateTime updatedAt;
  int schemaVersion;

  Exam({
    String? id,
    required this.name,
    List<Question>? questions,
    this.description = '',
    this.category = '',
    this.provider = '',
    this.code = '',
    this.passingPercentage = 75,
    this.defaultDuration = 30,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.schemaVersion = 1,
  })  : id = (id != null && id.isNotEmpty) ? id : const Uuid().v4(),
        questions = questions ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
    reindexQuestions();
  }

  int get nextQuestionNumber => questions.length + 1;
  bool get isUntimed => defaultDuration == null || defaultDuration! <= 0;

  void addQuestions(List<Question> newQuestions) {
    questions.addAll(newQuestions);
    reindexQuestions();
    updatedAt = DateTime.now();
  }

  void reindexQuestions() {
    for (int i = 0; i < questions.length; i++) {
      questions[i].displayNumber = i + 1;
    }
  }

  Exam copyWith({
    String? id,
    String? name,
    List<Question>? questions,
    String? description,
    String? category,
    String? provider,
    String? code,
    int? passingPercentage,
    Object? defaultDuration = _unsetDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return Exam(
      id: id ?? this.id,
      name: name ?? this.name,
      questions: questions ?? List.from(this.questions),
      description: description ?? this.description,
      category: category ?? this.category,
      provider: provider ?? this.provider,
      code: code ?? this.code,
      passingPercentage: passingPercentage ?? this.passingPercentage,
      defaultDuration: identical(defaultDuration, _unsetDuration)
          ? this.defaultDuration
          : defaultDuration as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'provider': provider,
        'code': code,
        'passingPercentage': passingPercentage,
        'defaultDuration': defaultDuration,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory Exam.fromJson(Map<String, dynamic> j) {
    final list = (j['questions'] as List? ?? [])
        .map((x) => Question.fromJson(x as Map<String, dynamic>))
        .toList();

    DateTime parsedCreated = DateTime.now();
    if (j['createdAt'] != null) {
      parsedCreated =
          DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now();
    }

    DateTime parsedUpdated = parsedCreated;
    if (j['updatedAt'] != null) {
      parsedUpdated =
          DateTime.tryParse(j['updatedAt'].toString()) ?? parsedCreated;
    }

    final int? duration = j.containsKey('defaultDuration')
        ? (j['defaultDuration'] != null
            ? (j['defaultDuration'] as num).toInt()
            : null)
        : 30;

    final exam = Exam(
      id: j['id']?.toString(),
      name: j['name']?.toString() ?? 'Untitled Exam',
      description: j['description']?.toString() ?? '',
      category: j['category']?.toString() ?? '',
      provider: j['provider']?.toString() ?? '',
      code: j['code']?.toString() ?? '',
      passingPercentage: (j['passingPercentage'] as num?)?.toInt() ?? 75,
      defaultDuration: duration,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
      schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
      questions: list,
    );
    exam.reindexQuestions();
    return exam;
  }
}
