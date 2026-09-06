import '../models/question.dart';
import '../models/exam.dart';

enum ValidationSeverity { critical, warning, suggestion }

class ValidationIssue {
  final String field;
  final String message;
  final ValidationSeverity severity;

  const ValidationIssue({
    required this.field,
    required this.message,
    this.severity = ValidationSeverity.critical,
  });

  bool get isCritical => severity == ValidationSeverity.critical;
  bool get isWarning => severity == ValidationSeverity.warning;
  bool get isSuggestion => severity == ValidationSeverity.suggestion;

  @override
  String toString() => '[$severity] $field: $message';
}

class ValidationResult {
  final List<ValidationIssue> issues;

  const ValidationResult({this.issues = const []});

  bool get isValid => !issues.any((i) => i.isCritical);
  bool get hasWarnings => issues.any((i) => i.isWarning);
  bool get hasSuggestions => issues.any((i) => i.isSuggestion);

  List<ValidationIssue> get criticalIssues =>
      issues.where((i) => i.isCritical).toList();
  List<ValidationIssue> get warnings =>
      issues.where((i) => i.isWarning).toList();
  List<ValidationIssue> get suggestions =>
      issues.where((i) => i.isSuggestion).toList();

  List<String> get criticalMessages =>
      criticalIssues.map((i) => i.message).toList();
  List<String> get allMessages => issues.map((i) => i.message).toList();
}

class QuestionValidator {
  static List<String> validate(Question q, {int? index}) {
    final res = validateWithDetails(q, index: index);
    return res.criticalMessages;
  }

  static bool isValid(Question q) {
    final res = validateWithDetails(q);
    return res.isValid;
  }

  static ValidationResult validateWithDetails(Question q, {int? index}) {
    final issues = <ValidationIssue>[];
    final prefix = index != null ? 'Q#$index' : 'Question';

    // 1. Question text
    if (q.question.trim().isEmpty) {
      issues.add(ValidationIssue(
        field: '$prefix.question',
        message: 'Question text cannot be empty.',
        severity: ValidationSeverity.critical,
      ));
    } else if (q.question.trim().length < 3) {
      issues.add(ValidationIssue(
        field: '$prefix.question',
        message: 'Question text is very short.',
        severity: ValidationSeverity.warning,
      ));
    }

    // 2. Options validation
    final nonEmptyOptions =
        q.options.where((o) => o.trim().isNotEmpty).toList();
    if (nonEmptyOptions.length < 2) {
      issues.add(ValidationIssue(
        field: '$prefix.options',
        message: 'A question must have at least 2 non-empty options.',
        severity: ValidationSeverity.critical,
      ));
    } else if (q.options.length != 4) {
      issues.add(ValidationIssue(
        field: '$prefix.options',
        message:
            'Standard MCQs should preferably have 4 options (found ${q.options.length}).',
        severity: ValidationSeverity.suggestion,
      ));
    }

    // Check for duplicate options
    final seenOptions = <String>{};
    for (int i = 0; i < q.options.length; i++) {
      final opt = q.options[i].trim().toLowerCase();
      if (opt.isNotEmpty && seenOptions.contains(opt)) {
        issues.add(ValidationIssue(
          field: '$prefix.options[$i]',
          message:
              'Options must be unique (duplicate options detected: "${q.options[i]}").',
          severity: ValidationSeverity.critical,
        ));
      }
      seenOptions.add(opt);
    }

    // 3. Correct answers validation
    if (q.correctAnswers.isEmpty) {
      issues.add(ValidationIssue(
        field: '$prefix.correctAnswers',
        message: 'No correct answer specified.',
        severity: ValidationSeverity.critical,
      ));
    } else {
      for (final ans in q.correctAnswers) {
        if (ans < 0 || ans >= q.options.length) {
          issues.add(ValidationIssue(
            field: '$prefix.correctAnswers',
            message:
                'Correct answer index $ans is out of range (options: 0..${q.options.length - 1}).',
            severity: ValidationSeverity.critical,
          ));
        }
      }
    }

    // 4. Difficulty validation
    if (q.difficulty < 1 || q.difficulty > 5) {
      issues.add(ValidationIssue(
        field: '$prefix.difficulty',
        message: 'Difficulty must be between 1 and 5.',
        severity: ValidationSeverity.critical,
      ));
    }

    return ValidationResult(issues: issues);
  }
}

class ExamValidator {
  static List<String> validate(Exam exam) {
    final res = validateWithDetails(exam);
    return res.criticalMessages;
  }

  static bool isValid(Exam exam) {
    final res = validateWithDetails(exam);
    return res.isValid;
  }

  static ValidationResult validateWithDetails(Exam exam) {
    final issues = <ValidationIssue>[];

    // 1. Name
    if (exam.name.trim().isEmpty) {
      issues.add(const ValidationIssue(
        field: 'exam.name',
        message: 'Exam name cannot be empty.',
        severity: ValidationSeverity.critical,
      ));
    }

    // 2. Questions
    if (exam.questions.isEmpty) {
      issues.add(const ValidationIssue(
        field: 'exam.questions',
        message: 'Exam contains no questions.',
        severity: ValidationSeverity.warning,
      ));
    } else {
      for (int i = 0; i < exam.questions.length; i++) {
        final qResult = QuestionValidator.validateWithDetails(exam.questions[i],
            index: i + 1);
        issues.addAll(qResult.issues);
      }
    }

    // 3. Passing Percentage
    if (exam.passingPercentage < 1 || exam.passingPercentage > 100) {
      issues.add(const ValidationIssue(
        field: 'exam.passingPercentage',
        message: 'Passing percentage must be between 1 and 100.',
        severity: ValidationSeverity.critical,
      ));
    }

    // 4. Default Duration
    if (exam.defaultDuration != null && exam.defaultDuration! < 0) {
      issues.add(const ValidationIssue(
        field: 'exam.defaultDuration',
        message: 'Duration cannot be negative (use 0 for untimed).',
        severity: ValidationSeverity.critical,
      ));
    }

    return ValidationResult(issues: issues);
  }
}

class SessionValidator {
  static List<String> validate({
    required String examId,
    required List<String> questionIds,
    required int currentIndex,
    required int remainingSeconds,
    Map<String, Set<int>>? userAnswers,
  }) {
    final issues = <String>[];
    if (examId.trim().isEmpty) {
      issues.add('Exam ID is required for a session.');
    }
    if (questionIds.isEmpty) {
      issues.add('Session must include question IDs.');
    }
    if (currentIndex < 0 ||
        (questionIds.isNotEmpty && currentIndex >= questionIds.length)) {
      issues.add('Current question index $currentIndex is out of bounds.');
    }
    if (remainingSeconds < 0) {
      issues.add('Remaining seconds cannot be negative.');
    }
    return issues;
  }

  static bool isValidSession(
      Map<String, dynamic>? session, List<Question> examQuestions) {
    if (session == null) return false;
    try {
      final examId = session['examId']?.toString();
      if (examId == null || examId.isEmpty) return false;

      final questionIds = (session['questionIds'] as List?)?.cast<String>();
      if (questionIds == null || questionIds.isEmpty) return false;

      final validIds = examQuestions.map((q) => q.id).toSet();
      if (!questionIds.any((id) => validIds.contains(id))) return false;

      final currentIndex = session['currentIndex'] as int?;
      if (currentIndex != null &&
          (currentIndex < 0 || currentIndex >= questionIds.length)) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
