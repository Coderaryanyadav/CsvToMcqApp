import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/student_profile.dart';
import 'package:csv_to_mcq_app/models/performance.dart';

void main() {
  group('StudentProfile Model Tests', () {
    test('StudentProfile model instantiates and serializes to JSON correctly',
        () {
      final student = StudentProfile(
        id: 'student_1',
        name: 'Aryan Yadav',
        avatarEmoji: '⚡',
        avatarColorValue: 0xFF2563EB,
        createdAt: DateTime(2026, 9, 6, 12, 0),
      );

      final json = student.toJson();
      expect(json['id'], 'student_1');
      expect(json['name'], 'Aryan Yadav');
      expect(json['avatarEmoji'], '⚡');
      expect(json['avatarColorValue'], 0xFF2563EB);

      final fromJson = StudentProfile.fromJson(json);
      expect(fromJson.id, student.id);
      expect(fromJson.name, student.name);
      expect(fromJson.avatarEmoji, student.avatarEmoji);
      expect(fromJson.avatarColorValue, student.avatarColorValue);
    });

    test('ExamPerformance model preserves studentId and studentName', () {
      final perf = ExamPerformance(
        studentId: 'student_2',
        studentName: 'Rohan Sharma',
        examId: 'aws_exam_1',
        examName: 'AWS Certified Solutions Architect',
        date: DateTime(2026, 9, 6, 15, 30),
        totalQuestions: 20,
        correct: 18,
        incorrect: 2,
        unanswered: 0,
        durationSeconds: 1200,
        passingPercentage: 75,
      );

      expect(perf.studentId, 'student_2');
      expect(perf.studentName, 'Rohan Sharma');
      expect(perf.percentage, 90.0);
      expect(perf.passed, true);

      final json = perf.toJson();
      expect(json['studentId'], 'student_2');
      expect(json['studentName'], 'Rohan Sharma');

      final fromJson = ExamPerformance.fromJson(json);
      expect(fromJson.studentId, 'student_2');
      expect(fromJson.studentName, 'Rohan Sharma');
    });
  });
}
