import 'dart:math';
import 'package:flutter/material.dart';
import '../models/question.dart';

/// Metadata for a question type
class QuestionTypeInfo {
  final String id;
  final String displayName;
  final IconData icon;

  const QuestionTypeInfo({
    required this.id,
    required this.displayName,
    required this.icon,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionTypeInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Helper for standard question types & schema discovery
class QuestionTypeHelper {
  static const String typeSingle = 'single';
  static const String typeMultiple = 'multiple';
  static const String typeTrueFalse = 'true_false';

  static String getCanonicalType(Question q) {
    if (q.isMultiple) return typeMultiple;
    final raw = q.questionType.trim().toLowerCase();
    if (raw == 'multiple' || raw == 'multi' || raw == 'multiple_choice') {
      return typeMultiple;
    }
    if (raw == 'single' || raw == 'single_choice' || raw == 'mcq') {
      return typeSingle;
    }
    if (raw == 'true_false' || raw == 'tf' || raw == 'boolean') {
      return typeTrueFalse;
    }
    return raw.isNotEmpty ? raw : typeSingle;
  }

  static String getDisplayName(String typeId) {
    switch (typeId.toLowerCase()) {
      case typeSingle:
      case 'single_choice':
      case 'mcq':
        return 'Single Choice';
      case typeMultiple:
      case 'multiple_choice':
      case 'multi':
        return 'Multiple Choice';
      case typeTrueFalse:
      case 'tf':
      case 'boolean':
        return 'True / False';
      default:
        // Format snake_case or camelCase to Title Case
        return typeId
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty
                ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
                : '')
            .join(' ');
    }
  }

  static IconData getIcon(String typeId) {
    switch (typeId.toLowerCase()) {
      case typeSingle:
      case 'single_choice':
      case 'mcq':
        return Icons.radio_button_checked;
      case typeMultiple:
      case 'multiple_choice':
      case 'multi':
        return Icons.check_box_outlined;
      case typeTrueFalse:
      case 'tf':
      case 'boolean':
        return Icons.rule_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  /// Discovers all unique question types present in a list of questions
  static List<QuestionTypeInfo> discoverTypes(List<Question> questions) {
    final Map<String, QuestionTypeInfo> detected = {};

    // Standard ordering preference: single, multiple, then others
    for (final q in questions) {
      final canonical = getCanonicalType(q);
      if (!detected.containsKey(canonical)) {
        detected[canonical] = QuestionTypeInfo(
          id: canonical,
          displayName: getDisplayName(canonical),
          icon: getIcon(canonical),
        );
      }
    }

    // If no questions yet, default to standard single & multiple
    if (detected.isEmpty) {
      return const [
        QuestionTypeInfo(
          id: typeSingle,
          displayName: 'Single Choice',
          icon: Icons.radio_button_checked,
        ),
        QuestionTypeInfo(
          id: typeMultiple,
          displayName: 'Multiple Choice',
          icon: Icons.check_box_outlined,
        ),
      ];
    }

    // Sort: single first, multiple second, then alphabetical
    final list = detected.values.toList();
    list.sort((a, b) {
      if (a.id == typeSingle) return -1;
      if (b.id == typeSingle) return 1;
      if (a.id == typeMultiple) return -1;
      if (b.id == typeMultiple) return 1;
      return a.displayName.compareTo(b.displayName);
    });
    return list;
  }
}

/// Availability calculation result for a question bank
class QuestionAvailability {
  final int totalAvailable;
  final Map<String, int> countsByType;
  final int totalStarred;

  const QuestionAvailability({
    required this.totalAvailable,
    required this.countsByType,
    required this.totalStarred,
  });

  int getCountForType(String typeId) => countsByType[typeId] ?? 0;
}

/// Core service for querying, filtering, and validating questions for Practice and Exam flows
class QuestionSelectionService {
  /// Discovers all unique chapters present in questions
  static List<String> discoverChapters(List<Question> questions) {
    final Set<String> set = {};
    for (final q in questions) {
      if (q.chapter != null && q.chapter!.trim().isNotEmpty) {
        set.add(q.chapter!.trim());
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Discovers all unique topics present in questions, optionally filtered by active chapter
  static List<String> discoverTopics(
    List<Question> questions, {
    String? selectedChapter,
  }) {
    final Set<String> set = {};
    for (final q in questions) {
      if (selectedChapter != null &&
          selectedChapter.isNotEmpty &&
          selectedChapter != 'All Chapters') {
        if (q.chapter != selectedChapter) continue;
      }
      if (q.topic != null && q.topic!.trim().isNotEmpty) {
        set.add(q.topic!.trim());
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Computes availability counts given current base filters (chapter, topic, difficulty, starred)
  static QuestionAvailability getAvailability({
    required List<Question> questions,
    String? selectedChapter,
    String? selectedTopic,
    String? selectedDifficulty,
    bool onlyStarred = false,
    Set<String> bookmarkedIds = const {},
  }) {
    var filtered = List<Question>.from(questions);

    if (onlyStarred) {
      filtered = filtered.where((q) => bookmarkedIds.contains(q.id)).toList();
    }

    if (selectedChapter != null &&
        selectedChapter.isNotEmpty &&
        selectedChapter != 'All Chapters') {
      filtered = filtered.where((q) => q.chapter == selectedChapter).toList();
    }

    if (selectedTopic != null &&
        selectedTopic.isNotEmpty &&
        selectedTopic != 'All Topics') {
      filtered = filtered.where((q) => q.topic == selectedTopic).toList();
    }

    if (selectedDifficulty != null &&
        selectedDifficulty.isNotEmpty &&
        selectedDifficulty != 'Any') {
      if (selectedDifficulty == 'Easy') {
        filtered = filtered.where((q) => q.difficulty <= 2).toList();
      } else if (selectedDifficulty == 'Medium') {
        filtered = filtered
            .where((q) => q.difficulty == 3 || q.difficulty == 4)
            .toList();
      } else if (selectedDifficulty == 'Hard') {
        filtered = filtered.where((q) => q.difficulty == 5).toList();
      }
    }

    final countsByType = <String, int>{};
    for (final q in filtered) {
      final canonical = QuestionTypeHelper.getCanonicalType(q);
      countsByType[canonical] = (countsByType[canonical] ?? 0) + 1;
    }

    final starredCount =
        questions.where((q) => bookmarkedIds.contains(q.id)).length;

    return QuestionAvailability(
      totalAvailable: filtered.length,
      countsByType: countsByType,
      totalStarred: starredCount,
    );
  }

  /// Filters questions using the selected criteria, question types, count, and shuffle options
  static List<Question> filterQuestions({
    required List<Question> questions,
    Set<String>? selectedQuestionTypes,
    bool isAllQuestionTypes = true,
    String? selectedChapter,
    String? selectedTopic,
    String? selectedDifficulty,
    bool onlyStarred = false,
    Set<String> bookmarkedIds = const {},
    bool shuffleQuestions = false,
    bool shuffleOptions = false,
    int? count,
    bool isAllQuestions = false,
  }) {
    if (questions.isEmpty) return [];

    var list = List<Question>.from(questions);

    // 1. Filter by question types
    if (!isAllQuestionTypes &&
        selectedQuestionTypes != null &&
        selectedQuestionTypes.isNotEmpty) {
      list = list.where((q) {
        final canonical = QuestionTypeHelper.getCanonicalType(q);
        return selectedQuestionTypes.contains(canonical);
      }).toList();
    }

    // 2. Filter by starred / bookmarked
    if (onlyStarred) {
      list = list.where((q) => bookmarkedIds.contains(q.id)).toList();
    }

    // 3. Filter by chapter
    if (selectedChapter != null &&
        selectedChapter.isNotEmpty &&
        selectedChapter != 'All Chapters') {
      list = list.where((q) => q.chapter == selectedChapter).toList();
    }

    // 4. Filter by topic
    if (selectedTopic != null &&
        selectedTopic.isNotEmpty &&
        selectedTopic != 'All Topics') {
      list = list.where((q) => q.topic == selectedTopic).toList();
    }

    // 5. Filter by difficulty
    if (selectedDifficulty != null &&
        selectedDifficulty.isNotEmpty &&
        selectedDifficulty != 'Any') {
      if (selectedDifficulty == 'Easy') {
        list = list.where((q) => q.difficulty <= 2).toList();
      } else if (selectedDifficulty == 'Medium') {
        list =
            list.where((q) => q.difficulty == 3 || q.difficulty == 4).toList();
      } else if (selectedDifficulty == 'Hard') {
        list = list.where((q) => q.difficulty == 5).toList();
      }
    }

    // 5. Shuffle questions sequence if enabled (keeps selected question types intact)
    if (shuffleQuestions) {
      list.shuffle();
    }

    // 6. Shuffle options if enabled (preserves correct answers & explanation mappings)
    if (shuffleOptions) {
      list = list.map((origQ) {
        final originalCorrectOptions =
            origQ.correctAnswers.map((idx) => origQ.options[idx]).toSet();
        final optionsCopy = List<String>.from(origQ.options)..shuffle();
        final newCorrectAnswers = <int>{};
        final newExplanations = <int, String>{};

        for (int i = 0; i < optionsCopy.length; i++) {
          if (originalCorrectOptions.contains(optionsCopy[i])) {
            newCorrectAnswers.add(i);
          }
          final oldIdx = origQ.options.indexOf(optionsCopy[i]);
          if (oldIdx != -1 && origQ.optionExplanations.containsKey(oldIdx)) {
            newExplanations[i] = origQ.optionExplanations[oldIdx]!;
          }
        }

        return origQ.copyWith(
          options: optionsCopy,
          correctAnswers: newCorrectAnswers,
          optionExplanations: newExplanations,
        );
      }).toList();
    }

    // 7. Slicing question count
    if (isAllQuestions || count == null || count <= 0) {
      return list;
    }

    final takeCount = min(count, list.length);
    return list.take(max(1, takeCount)).toList();
  }

  /// Validates the selection parameters and returns a user-friendly error message if invalid
  static String? validateSelection({
    required int availableCount,
    required int requestedCount,
    required Set<String> selectedQuestionTypes,
    required bool isAllQuestionTypes,
    required List<QuestionTypeInfo> allAvailableTypes,
    bool onlyStarred = false,
    String? examName,
  }) {
    if (!isAllQuestionTypes && selectedQuestionTypes.isEmpty) {
      return 'Please select at least one question type.';
    }

    if (availableCount == 0) {
      if (onlyStarred) {
        return 'No starred / bookmarked questions found in "${examName ?? 'Exam'}". Star questions during practice or in the Question Bank first.';
      }
      final typesDesc = isAllQuestionTypes
          ? 'selected filters'
          : selectedQuestionTypes
              .map((t) => QuestionTypeHelper.getDisplayName(t))
              .join(', ');
      return 'No questions available in "${examName ?? 'Exam'}" for $typesDesc with current filters.';
    }

    if (requestedCount <= 0) {
      return 'Please enter a question count greater than 0.';
    }

    if (requestedCount > availableCount) {
      final typesDesc = isAllQuestionTypes
          ? 'this exam track/filter'
          : selectedQuestionTypes
              .map((t) => QuestionTypeHelper.getDisplayName(t))
              .join(', ');
      return 'Only $availableCount questions are available for $typesDesc. Please reduce the number of questions or select additional question types.';
    }

    return null;
  }
}
