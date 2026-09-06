import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/exam.dart';
import 'package:csv_to_mcq_app/models/question.dart';
import 'package:csv_to_mcq_app/models/performance.dart';

void main() {
  group('Exam & Performance Model Serialization Tests', () {
    test(
        'Exam JSON serialization preserves schemaVersion, metadata, and questions',
        () {
      final exam = Exam(
        id: 'exam_aws',
        name: 'AWS SAA-C03',
        description: 'Solutions Architect Associate',
        category: 'Cloud',
        provider: 'Amazon',
        code: 'SAA-C03',
        passingPercentage: 72,
        defaultDuration: 130,
        schemaVersion: 1,
        questions: [
          Question(
            id: 'q1',
            question: 'What is S3?',
            options: [
              'Object Storage',
              'Block Storage',
              'File Storage',
              'Compute'
            ],
            correctAnswers: {0},
            displayNumber: 1,
          ),
        ],
      );

      final json = exam.toJson();
      expect(json['schemaVersion'], 1);
      expect(json['passingPercentage'], 72);
      expect(json['defaultDuration'], 130);
      expect(json['provider'], 'Amazon');

      final revived = Exam.fromJson(json);
      expect(revived.id, 'exam_aws');
      expect(revived.name, 'AWS SAA-C03');
      expect(revived.passingPercentage, 72);
      expect(revived.defaultDuration, 130);
      expect(revived.questions.length, 1);
      expect(revived.questions.first.question, 'What is S3?');
    });

    test(
        'Performance model correctly evaluates passing status against custom threshold',
        () {
      final passPerf = Performance(
        examName: 'Hard Exam',
        score: 75.0,
        correct: 15,
        total: 20,
        passingPercentage: 70,
      );
      expect(passPerf.passed, isTrue);

      final failPerf = Performance(
        examName: 'Hard Exam',
        score: 65.0,
        correct: 13,
        total: 20,
        passingPercentage: 70,
      );
      expect(failPerf.passed, isFalse);
    });

    test('Exam addQuestions increments nextQuestionNumber reliably', () {
      final exam = Exam(name: 'Test Exam');
      expect(exam.nextQuestionNumber, 1);

      exam.addQuestions([
        Question(question: 'Q1', options: ['A', 'B'], correctAnswers: {0}),
        Question(question: 'Q2', options: ['A', 'B'], correctAnswers: {1}),
      ]);

      expect(exam.questions.length, 2);
      expect(exam.nextQuestionNumber, 3);
    });
  });
}
