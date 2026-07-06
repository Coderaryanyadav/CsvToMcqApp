import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/services/excel_service.dart';

void main() {
  group('ExcelService CSV Parsing Tests', () {
    test('Standard CSV format is parsed correctly', () async {
      const csv = 'Question,Option 1,Option 2,Option 3,Option 4,Correct Answer\nWhat is 1+1?,1,2,3,4,2\nCapital of India?,Mumbai,Delhi,Kolkata,Chennai,2\n';
      final exam = await ExcelService.importFromCsvString(csv);
      expect(exam.questions.length, 2);
      expect(exam.questions[0].question, 'What is 1+1?');
      expect(exam.questions[0].options[1], '2');
      expect(exam.questions[1].question, 'Capital of India?');
      expect(exam.questions[1].options[1], 'Delhi');
    });

    test('CSV with complex quotes and newlines inside fields is parsed correctly', () async {
      const csv = 'Question,Option 1,Option 2,Option 3,Option 4,Correct Answer\n"What is 1+1?\nWait, maybe 2?",1,2,3,4,1\n"He said, ""Hello""",yes,no,maybe,so,0\n';
      final exam = await ExcelService.importFromCsvString(csv);
      expect(exam.questions.length, 2);
      expect(exam.questions[0].question, 'What is 1+1?\nWait, maybe 2?');
      expect(exam.questions[0].correct, 0);
      expect(exam.questions[1].question, 'He said, "Hello"');
      expect(exam.questions[1].correct, 0);
    });

    test('CSV throws error if required columns are missing', () async {
      const csv = 'Question,Option 1,Option 2,Option 3\nWhat is 1+1?,1,2,3\n';
      expect(() => ExcelService.importFromCsvString(csv), throwsA(isA<String>()));
    });
    
    test('CSV throws error if no valid questions found', () async {
      const csv = 'Question,Option 1,Option 2,Option 3,Option 4,Correct Answer\n';
      expect(() => ExcelService.importFromCsvString(csv), throwsA(isA<String>()));
    });
  });
}
