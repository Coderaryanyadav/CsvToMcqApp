import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/services/import_service.dart';

void main() {
  test('CSV with UTF-8 BOM and standard headers parses 100% valid questions', () {
    const csvContent = '\uFEFFquestion_text,question_type,option_a,option_b,option_c,option_d,correct_answer,explanation_a,explanation_b,explanation_c,explanation_d\n'
        '"What is Amazon S3?",single,Object storage,Block storage,Database,Cache,A,Correct object storage,Incorrect,Incorrect,Incorrect\n'
        '"What is Amazon EC2?",single,Virtual servers,Serverless,Database,Storage,A,Correct compute,Incorrect,Incorrect,Incorrect\n';

    final result = ImportService.parseCsv(csvContent, 'test_bom.csv');
    expect(result.validCount, equals(2));
    expect(result.errorCount, equals(0));
    expect(result.validQuestions[0].question, equals('What is Amazon S3?'));
    expect(result.validQuestions[0].options[0], equals('Object storage'));
    expect(result.validQuestions[0].correctAnswers, equals({0}));
  });

  test('Real CIA Challenge Exam CSV file imports cleanly if file is present', () {
    final file = File('/Users/aryanyadav/Downloads/CIA_Challenge_Exam_100_App_Format.csv');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      final text = String.fromCharCodes(bytes); // Even if passed with BOM
      final result = ImportService.parseCsv(text, file.path);
      expect(result.validCount, equals(100));
      expect(result.errorCount, equals(0));
    }
  });
}
