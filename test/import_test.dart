import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/services/import_service.dart';
import 'package:csv_to_mcq_app/models/question.dart';
import 'package:csv_to_mcq_app/models/exam.dart';

void main() {
  group('ImportService CSV Parsing Tests', () {
    test('Standard CSV format is parsed correctly', () {
      const csv = 'Question,Option 1,Option 2,Option 3,Option 4,Correct Answer\nWhat is 1+1?,1,2,3,4,2\nCapital of India?,Mumbai,Delhi,Kolkata,Chennai,2\n';
      final result = ImportService.parseCsv(csv, 'test.csv');
      
      expect(result.criticalErrors, isEmpty);
      expect(result.validQuestions.length, 2);
      expect(result.validQuestions[0].question, 'What is 1+1?');
      expect(result.validQuestions[0].options[1], '2');
      expect(result.validQuestions[0].correct, 1);
      
      expect(result.validQuestions[1].question, 'Capital of India?');
      expect(result.validQuestions[1].options[1], 'Delhi');
      expect(result.validQuestions[1].correct, 1);
    });

    test('Multiple select CSV format (A|C) and 4 option explanations are parsed correctly', () {
      const csv = '''question_text,question_type,option_a,option_b,option_c,option_d,correct_answer,explanation_a,explanation_b,explanation_c,explanation_d,topic,difficulty
"Which are relational databases?",multiple,PostgreSQL,MongoDB,MySQL,Redis,A|C,"PostgreSQL is RDBMS","MongoDB is document store","MySQL is RDBMS","Redis is in-memory key-value",Databases,3''';
      
      final result = ImportService.parseCsv(csv, 'multi_test.csv', startQuestionNumber: 151);

      expect(result.criticalErrors, isEmpty);
      expect(result.validQuestions.length, 1);
      final q = result.validQuestions.first;
      expect(q.id, 'Q151');
      expect(q.isMultiple, true);
      expect(q.correctAnswers, {0, 2});
      expect(q.getExplanation(0), 'PostgreSQL is RDBMS');
      expect(q.getExplanation(1), 'MongoDB is document store');
      expect(q.getExplanation(2), 'MySQL is RDBMS');
      expect(q.getExplanation(3), 'Redis is in-memory key-value');
      expect(q.topic, 'Databases');
      expect(q.difficulty, 3);
    });

    test('Starting question number assigns sequential IDs accurately', () {
      const csv = '''Question,Option A,Option B,Option C,Option D,Correct
Q One,A,B,C,D,A
Q Two,A,B,C,D,B
Q Three,A,B,C,D,C''';
      
      final result = ImportService.parseCsv(csv, 'seq.csv', startQuestionNumber: 301);

      expect(result.validQuestions.length, 3);
      expect(result.validQuestions[0].id, 'Q301');
      expect(result.validQuestions[1].id, 'Q302');
      expect(result.validQuestions[2].id, 'Q303');
    });

    test('CSV with complex quotes and newlines inside fields is parsed correctly', () {
      const csv = 'Question,Option A,Option B,Option C,Option D,Correct\n"What is 1+1?\nWait, maybe 2?",1,2,3,4,A\n"He said, ""Hello""",yes,no,maybe,so,A\n';
      final result = ImportService.parseCsv(csv, 'test.csv');
      
      expect(result.criticalErrors, isEmpty);
      expect(result.validQuestions.length, 2);
      expect(result.validQuestions[0].question, 'What is 1+1?\nWait, maybe 2?');
      expect(result.validQuestions[0].correct, 0);
      
      expect(result.validQuestions[1].question, 'He said, "Hello"');
      expect(result.validQuestions[1].correct, 0);
    });

    test('Missing correct answer throws validation error', () {
      const csv = 'Question,Option 1,Option 2,Option 3,Option 4,Correct Answer\nWhat is 1+1?,1,2,3,4,\n';
      final result = ImportService.parseCsv(csv, 'test.csv');
      
      expect(result.criticalErrors.length, 1);
      expect(result.criticalErrors[0], contains('Missing correct answer'));
      expect(result.validQuestions, isEmpty);
    });
    
    test('Invalid correct answer format throws validation error', () {
      const csv = 'Question,Option 1,Option 2,Option 3,Option 4,Correct Answer\nWhat is 1+1?,1,2,3,4,5\n';
      final result = ImportService.parseCsv(csv, 'test.csv');
      
      expect(result.criticalErrors.length, 1);
      expect(result.criticalErrors[0], contains('Invalid correct answer'));
      expect(result.validQuestions, isEmpty);
    });
    
    test('Exact match answer text parses correctly', () {
      const csv = 'Question,Option 1,Option 2,Option 3,Option 4,Correct Answer\nCapital of France?,London,Berlin,Paris,Rome,Paris\n';
      final result = ImportService.parseCsv(csv, 'test.csv');
      
      expect(result.criticalErrors, isEmpty);
      expect(result.validQuestions.length, 1);
      expect(result.validQuestions[0].correct, 2);
    });
    
    test('Duplicate questions within the same import are rejected', () {
      const csv = 'Question,Option 1,Option 2,Option 3,Option 4,Correct Answer\nCapital of France?,London,Berlin,Paris,Rome,Paris\nCapital of France?,London,Berlin,Paris,Rome,Paris\n';
      final result = ImportService.parseCsv(csv, 'test.csv');
      
      expect(result.validQuestions.length, 1);
      expect(result.criticalErrors.length, 1);
      expect(result.criticalErrors[0], contains('Duplicate question detected'));
    });
  });

  group('Question Model & Grading Tests', () {
    test('Single select grading requires exact answer', () {
      final q = Question(
        id: 'Q1',
        question: 'Which SQL keyword retrieves data?',
        options: ['INSERT', 'SELECT', 'UPDATE', 'DELETE'],
        correctAnswers: {1},
      );

      expect(q.isAnswerCorrect({1}), true);
      expect(q.isAnswerCorrect({0}), false);
      expect(q.isAnswerCorrect({1, 2}), false);
      expect(q.isAnswerCorrect({}), false);
    });

    test('Multiple select grading requires exact matching set', () {
      final q = Question(
        id: 'Q2',
        question: 'Select cloud providers',
        options: ['AWS', 'GCP', 'Oracle DB', 'Azure'],
        correctAnswers: {0, 1, 3},
        questionType: 'multiple',
      );

      // Exact match
      expect(q.isAnswerCorrect({0, 1, 3}), true);

      // Partial selections must NOT be marked correct
      expect(q.isAnswerCorrect({0, 1}), false);
      expect(q.isAnswerCorrect({0}), false);
      expect(q.isAnswerCorrect({0, 1, 2, 3}), false);
      expect(q.isAnswerCorrect({}), false);
    });

    test('JSON serialization & deserialization preserves multi-answers and explanations', () {
      final q = Question(
        id: 'Q5',
        question: 'Test Q',
        options: ['A', 'B', 'C', 'D'],
        correctAnswers: {1, 3},
        questionType: 'multiple',
        optionExplanations: {
          1: 'B explanation',
          3: 'D explanation',
        },
        topic: 'Security',
        difficulty: 4,
      );

      final json = q.toJson();
      final revived = Question.fromJson(json);

      expect(revived.id, 'Q5');
      expect(revived.question, 'Test Q');
      expect(revived.correctAnswers, {1, 3});
      expect(revived.isMultiple, true);
      expect(revived.getExplanation(1), 'B explanation');
      expect(revived.getExplanation(3), 'D explanation');
      expect(revived.topic, 'Security');
      expect(revived.difficulty, 4);
    });

    test('Legacy Question JSON migration works seamlessly', () {
      final legacyJson = {
        'id': 'legacy_1',
        'question': 'Legacy single question',
        'options': ['Opt A', 'Opt B', 'Opt C', 'Opt D'],
        'correct': 2,
        'explanation': 'Overall explanation',
      };

      final migrated = Question.fromJson(legacyJson);
      expect(migrated.correctAnswers, {2});
      expect(migrated.isMultiple, false);
      expect(migrated.getExplanation(2), 'Overall explanation');
    });
  });

  group('Multiple Exams & Sequential ID Tests', () {
    test('Independent exams accumulate questions and maintain sequential IDs', () {
      final cia = Exam(id: 'cia', name: 'CIA', questions: []);
      final cisa = Exam(id: 'cisa', name: 'CISA', questions: []);

      expect(cia.nextQuestionNumber, 1);
      expect(cisa.nextQuestionNumber, 1);

      // Add 50 questions to CIA
      final ciaBatch1 = List.generate(
        50,
        (i) => Question(
          id: 'Q${cia.nextQuestionNumber + i}',
          question: 'CIA Question ${i + 1}',
          options: ['A', 'B', 'C', 'D'],
          correct: 0,
        ),
      );
      cia.addQuestions(ciaBatch1);
      expect(cia.questions.length, 50);
      expect(cia.nextQuestionNumber, 51);
      expect(cia.questions.first.id, 'Q1');
      expect(cia.questions.last.id, 'Q50');

      // CISA remains unaffected
      expect(cisa.questions.length, 0);
      expect(cisa.nextQuestionNumber, 1);

      // Add 100 more to CIA
      final ciaBatch2 = List.generate(
        100,
        (i) => Question(
          id: 'Q${cia.nextQuestionNumber + i}',
          question: 'CIA Question ${50 + i + 1}',
          options: ['A', 'B', 'C', 'D'],
          correct: 1,
        ),
      );
      cia.addQuestions(ciaBatch2);
      expect(cia.questions.length, 150);
      expect(cia.nextQuestionNumber, 151);
      expect(cia.questions.last.id, 'Q150');

      // Add 30 to CISA
      final cisaBatch1 = List.generate(
        30,
        (i) => Question(
          id: 'Q${cisa.nextQuestionNumber + i}',
          question: 'CISA Question ${i + 1}',
          options: ['A', 'B', 'C', 'D'],
          correct: 2,
        ),
      );
      cisa.addQuestions(cisaBatch1);
      expect(cisa.questions.length, 30);
      expect(cisa.nextQuestionNumber, 31);
      expect(cisa.questions.first.id, 'Q1');
      expect(cisa.questions.last.id, 'Q30');
    });
  });
}
