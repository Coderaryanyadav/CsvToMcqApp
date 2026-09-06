import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/question.dart';
import 'package:csv_to_mcq_app/models/exam.dart';
import 'package:csv_to_mcq_app/utils/validators.dart';

void main() {
  group('QuestionValidator Tests', () {
    test('Valid Question produces no validation errors', () {
      final q = Question(
        question: 'What is Dart?',
        options: ['A language', 'A browser', 'An OS', 'A database'],
        correctAnswers: {0},
        difficulty: 2,
        topic: 'Programming',
      );

      final errors = QuestionValidator.validate(q);
      expect(errors, isEmpty);
      expect(QuestionValidator.isValid(q), isTrue);
    });

    test('Empty question prompt fails validation', () {
      final q = Question(
        question: '   ',
        options: ['A', 'B'],
        correctAnswers: {0},
      );

      final errors = QuestionValidator.validate(q);
      expect(errors, contains('Question text cannot be empty.'));
      expect(QuestionValidator.isValid(q), isFalse);
    });

    test('Fewer than 2 options fails validation', () {
      final q = Question(
        question: 'What is 2+2?',
        options: ['4'],
        correctAnswers: {0},
      );

      final errors = QuestionValidator.validate(q);
      expect(errors,
          contains('A question must have at least 2 non-empty options.'));
    });

    test('Duplicate options fail validation', () {
      final q = Question(
        question: 'Select an option',
        options: ['Same', 'Same', 'Other'],
        correctAnswers: {0},
      );

      final errors = QuestionValidator.validate(q);
      expect(errors, contains(contains('duplicate options detected')));
    });

    test('Out of bounds correct answer fails validation', () {
      final q = Question(
        question: 'Valid question?',
        options: ['A', 'B'],
        correctAnswers: {5},
      );

      final errors = QuestionValidator.validate(q);
      expect(errors, contains(contains('out of range')));
    });

    test('Difficulty out of range fails validation', () {
      final q = Question(
        question: 'Valid question?',
        options: ['A', 'B'],
        correctAnswers: {0},
        difficulty: 10,
      );

      final errors = QuestionValidator.validate(q);
      expect(errors, contains('Difficulty must be between 1 and 5.'));
    });
  });

  group('ExamValidator Tests', () {
    test('Valid Exam passes validation', () {
      final exam = Exam(
        name: 'AWS Certified Cloud Practitioner',
        passingPercentage: 75,
        defaultDuration: 90,
      );

      final errors = ExamValidator.validate(exam);
      expect(errors, isEmpty);
      expect(ExamValidator.isValid(exam), isTrue);
    });

    test('Blank exam name fails validation', () {
      final exam = Exam(
        name: '   ',
        passingPercentage: 75,
      );

      final errors = ExamValidator.validate(exam);
      expect(errors, contains('Exam name cannot be empty.'));
      expect(ExamValidator.isValid(exam), isFalse);
    });

    test('Invalid passing percentage fails validation', () {
      final exam = Exam(
        name: 'Exam',
        passingPercentage: 150,
      );

      final errors = ExamValidator.validate(exam);
      expect(errors, contains('Passing percentage must be between 1 and 100.'));
    });

    test('Negative duration fails validation', () {
      final exam = Exam(
        name: 'Exam',
        passingPercentage: 75,
        defaultDuration: -10,
      );

      final errors = ExamValidator.validate(exam);
      expect(
          errors, contains('Duration cannot be negative (use 0 for untimed).'));
    });
  });

  group('SessionValidator Tests', () {
    test('Valid session parameters pass validation', () {
      final errors = SessionValidator.validate(
        examId: 'exam_123',
        questionIds: ['q1', 'q2', 'q3'],
        currentIndex: 1,
        remainingSeconds: 300,
        userAnswers: {
          'q1': {0},
          'q2': {1, 2},
        },
      );

      expect(errors, isEmpty);
    });

    test('Out of range current index fails validation', () {
      final errors = SessionValidator.validate(
        examId: 'exam_123',
        questionIds: ['q1', 'q2'],
        currentIndex: 5,
        remainingSeconds: 300,
      );

      expect(errors, contains(contains('out of bounds')));
    });

    test('Empty exam ID fails validation', () {
      final errors = SessionValidator.validate(
        examId: '',
        questionIds: ['q1'],
        currentIndex: 0,
        remainingSeconds: 100,
      );

      expect(errors, contains('Exam ID is required for a session.'));
    });
  });
}
