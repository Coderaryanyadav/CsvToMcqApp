import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/services/import_service.dart';

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

    test('CSV with complex quotes and newlines inside fields is parsed correctly', () {
      const csv = 'Question,Option A,Option B,Option C,Option D,Correct\n"What is 1+1?\nWait, maybe 2?",1,2,3,4,A\n"He said, ""Hello""",yes,no,maybe,so,A\n';
      final result = ImportService.parseCsv(csv, 'test.csv');
      
      expect(result.criticalErrors, isEmpty);
      expect(result.validQuestions.length, 2);
      expect(result.validQuestions[0].question, 'What is 1+1?\nWait, maybe 2?');
      expect(result.validQuestions[0].correct, 0); // 'A' means index 0
      
      expect(result.validQuestions[1].question, 'He said, "Hello"');
      expect(result.validQuestions[1].correct, 0); // 'A' means index 0
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
    
    test('Duplicate questions are rejected', () {
      const csv = 'Question,Option 1,Option 2,Option 3,Option 4,Correct Answer\nCapital of France?,London,Berlin,Paris,Rome,Paris\nCapital of France?,London,Berlin,Paris,Rome,Paris\n';
      final result = ImportService.parseCsv(csv, 'test.csv');
      
      expect(result.validQuestions.length, 1);
      expect(result.criticalErrors.length, 1);
      expect(result.criticalErrors[0], contains('Duplicate question detected'));
    });
  });
}
