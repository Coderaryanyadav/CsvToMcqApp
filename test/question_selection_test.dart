import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/question.dart';
import 'package:csv_to_mcq_app/services/question_selection_service.dart';

void main() {
  group('QuestionSelectionService Tests', () {
    late List<Question> sampleQuestions;

    setUp(() {
      sampleQuestions = [
        Question(
          id: 'q1',
          question: 'Single Choice Question 1',
          options: ['A', 'B', 'C', 'D'],
          correctAnswers: {0},
          questionType: 'single',
          topic: 'Math',
          difficulty: 1,
        ),
        Question(
          id: 'q2',
          question: 'Single Choice Question 2',
          options: ['A', 'B', 'C', 'D'],
          correctAnswers: {1},
          questionType: 'single',
          topic: 'Math',
          difficulty: 2,
        ),
        Question(
          id: 'q3',
          question: 'Single Choice Question 3',
          options: ['A', 'B', 'C', 'D'],
          correctAnswers: {2},
          questionType: 'single',
          topic: 'Science',
          difficulty: 3,
        ),
        Question(
          id: 'q4',
          question: 'Multiple Choice Question 1',
          options: ['A', 'B', 'C', 'D'],
          correctAnswers: {0, 2},
          questionType: 'multiple',
          topic: 'Math',
          difficulty: 3,
        ),
        Question(
          id: 'q5',
          question: 'Multiple Choice Question 2',
          options: ['A', 'B', 'C', 'D'],
          correctAnswers: {1, 3},
          questionType: 'multiple',
          topic: 'Science',
          difficulty: 5,
        ),
        Question(
          id: 'q6',
          question: 'True False Question 1',
          options: ['True', 'False'],
          correctAnswers: {0},
          questionType: 'true_false',
          topic: 'General',
          difficulty: 1,
        ),
      ];
    });

    test('discoverTypes returns all unique question types with proper metadata',
        () {
      final types = QuestionTypeHelper.discoverTypes(sampleQuestions);
      expect(types.length, 3);
      expect(types[0].id, 'single');
      expect(types[0].displayName, 'Single Choice');
      expect(types[1].id, 'multiple');
      expect(types[1].displayName, 'Multiple Choice');
      expect(types[2].id, 'true_false');
      expect(types[2].displayName, 'True / False');
    });

    test('getAvailability computes total and per-type availability counts', () {
      final avail = QuestionSelectionService.getAvailability(
        questions: sampleQuestions,
      );

      expect(avail.totalAvailable, 6);
      expect(avail.getCountForType('single'), 3);
      expect(avail.getCountForType('multiple'), 2);
      expect(avail.getCountForType('true_false'), 1);
    });

    test('getAvailability respects base filters like topic and difficulty', () {
      final avail = QuestionSelectionService.getAvailability(
        questions: sampleQuestions,
        selectedTopic: 'Math',
        selectedDifficulty: 'Easy',
      );

      // In Math with Easy difficulty (<=2): q1 and q2 (both single)
      expect(avail.totalAvailable, 2);
      expect(avail.getCountForType('single'), 2);
      expect(avail.getCountForType('multiple'), 0);
    });

    test('Filter by Multiple Choice only returns zero single choice questions',
        () {
      final results = QuestionSelectionService.filterQuestions(
        questions: sampleQuestions,
        selectedQuestionTypes: {'multiple'},
        isAllQuestionTypes: false,
      );

      expect(results.length, 2);
      expect(results.every((q) => q.isMultiple), isTrue);
      expect(results.every((q) => q.questionType == 'multiple'), isTrue);
      expect(results.map((q) => q.id).toSet(), {'q4', 'q5'});
    });

    test('Filter by Single Choice only returns zero multiple choice questions',
        () {
      final results = QuestionSelectionService.filterQuestions(
        questions: sampleQuestions,
        selectedQuestionTypes: {'single'},
        isAllQuestionTypes: false,
      );

      expect(results.length, 3);
      expect(results.every((q) => !q.isMultiple), isTrue);
      expect(results.every((q) => q.questionType == 'single'), isTrue);
      expect(results.map((q) => q.id).toSet(), {'q1', 'q2', 'q3'});
    });

    test('Multi-select (Single Choice + True/False) returns only those types',
        () {
      final results = QuestionSelectionService.filterQuestions(
        questions: sampleQuestions,
        selectedQuestionTypes: {'single', 'true_false'},
        isAllQuestionTypes: false,
      );

      expect(results.length, 4);
      expect(results.any((q) => q.isMultiple), isFalse);
      expect(results.map((q) => q.id).toSet(), {'q1', 'q2', 'q3', 'q6'});
    });

    test('All Question Types returns all supported questions', () {
      final results = QuestionSelectionService.filterQuestions(
        questions: sampleQuestions,
        isAllQuestionTypes: true,
      );

      expect(results.length, 6);
      expect(results.map((q) => q.id).toSet(),
          {'q1', 'q2', 'q3', 'q4', 'q5', 'q6'});
    });

    test(
        'Shuffle Questions randomizes ordering without altering question types',
        () {
      // Run filtering with shuffle enabled for multiple choice
      final results = QuestionSelectionService.filterQuestions(
        questions: sampleQuestions,
        selectedQuestionTypes: {'multiple'},
        isAllQuestionTypes: false,
        shuffleQuestions: true,
      );

      expect(results.length, 2);
      expect(results.every((q) => q.isMultiple), isTrue);
      expect(results.map((q) => q.id).toSet(), {'q4', 'q5'});
    });

    test('Requested question count is strictly capped to available questions',
        () {
      final results = QuestionSelectionService.filterQuestions(
        questions: sampleQuestions,
        selectedQuestionTypes: {'multiple'},
        isAllQuestionTypes: false,
        count: 10, // User requested 10, but only 2 multiple choice exist
      );

      // Must NOT add single choice questions to reach count!
      expect(results.length, 2);
      expect(results.every((q) => q.isMultiple), isTrue);
    });

    test('Taking fewer than available returns the requested count', () {
      final results = QuestionSelectionService.filterQuestions(
        questions: sampleQuestions,
        selectedQuestionTypes: {'single'},
        isAllQuestionTypes: false,
        count: 2,
      );

      expect(results.length, 2);
      expect(results.every((q) => q.questionType == 'single'), isTrue);
    });

    test('Validation detects zero selected question types', () {
      final error = QuestionSelectionService.validateSelection(
        availableCount: 0,
        requestedCount: 10,
        selectedQuestionTypes: {},
        isAllQuestionTypes: false,
        allAvailableTypes: QuestionTypeHelper.discoverTypes(sampleQuestions),
      );

      expect(error, contains('select at least one question type'));
    });

    test('Validation detects when requested count exceeds available count', () {
      final error = QuestionSelectionService.validateSelection(
        availableCount: 2,
        requestedCount: 10,
        selectedQuestionTypes: {'multiple'},
        isAllQuestionTypes: false,
        allAvailableTypes: QuestionTypeHelper.discoverTypes(sampleQuestions),
        examName: 'Math Exam',
      );

      expect(error, contains('Only 2 questions are available'));
      expect(error, contains('Multiple Choice'));
    });

    test('Validation passes when requested count <= available count', () {
      final error = QuestionSelectionService.validateSelection(
        availableCount: 3,
        requestedCount: 2,
        selectedQuestionTypes: {'single'},
        isAllQuestionTypes: false,
        allAvailableTypes: QuestionTypeHelper.discoverTypes(sampleQuestions),
      );

      expect(error, isNull);
    });
  });
}
