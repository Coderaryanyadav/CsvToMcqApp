import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/exam.dart';
import 'package:csv_to_mcq_app/models/question.dart';
import 'package:csv_to_mcq_app/models/performance.dart';
import 'package:csv_to_mcq_app/models/student_profile.dart';
import 'package:csv_to_mcq_app/repositories/storage_repository.dart';
import 'package:csv_to_mcq_app/services/storage_service.dart';

class TestStorageRepository extends IoStorageRepository {
  final Directory customDir;

  TestStorageRepository(this.customDir);

  @override
  Future<void> init() async {
    appDir = customDir;
    tempDir = Directory('${customDir.path}/temp');
    mcqDir = Directory('${customDir.path}/mcq_data');
    if (!await mcqDir.exists()) {
      await mcqDir.create(recursive: true);
    }
  }
}

void main() {
  late Directory tempTestDir;

  setUp(() async {
    tempTestDir =
        await Directory.systemTemp.createTemp('mcq_db_persistence_test_');
  });

  tearDown(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  group('Database & Cold Restart Persistence Tests', () {
    test(
        'Simulate App Session 1 -> Save Data -> App Close -> App Session 2 Cold Restart -> Verify Full Data Integrity',
        () async {
      // ==========================================
      // SESSION 1: User opens app for the 1st time
      // ==========================================
      final session1Repo = TestStorageRepository(tempTestDir);
      StorageService.setRepository(session1Repo);
      await StorageService.init();

      // 1. Create multiple student profiles
      final studentAlice = StudentProfile(
        id: 'student-alice-1',
        name: 'Alice Johnson',
        avatarEmoji: '👩‍💻',
        avatarColorValue: 0xFF6366F1,
        createdAt: DateTime(2026, 1, 1),
      );
      final studentBob = StudentProfile(
        id: 'student-bob-2',
        name: 'Bob Smith',
        avatarEmoji: '👨‍🎓',
        avatarColorValue: 0xFF10B981,
        createdAt: DateTime(2026, 1, 2),
      );
      await StorageService.saveStudent(studentAlice);
      await StorageService.saveStudent(studentBob);
      await StorageService.setActiveStudent(studentAlice);

      // 2. Create custom exam with multiple choice questions
      final sampleExam = Exam(
        id: 'exam-aws-cloud',
        name: 'AWS Solutions Architect',
        defaultDuration: 45,
        passingPercentage: 80,
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 1, 10),
        questions: [
          Question(
            id: 'q1',
            displayNumber: 1,
            question: 'What is Amazon S3 primarily used for?',
            options: [
              'Object Storage',
              'Block Storage',
              'Relational Database',
              'Message Broker'
            ],
            correctAnswers: {0},
            difficulty: 2,
            topic: 'Storage',
            tags: ['AWS', 'S3'],
            optionExplanations: {0: 'S3 provides scalable object storage.'},
          ),
          Question(
            id: 'q2',
            displayNumber: 2,
            questionType: 'multiple',
            question: 'Which services provide serverless compute? (Choose two)',
            options: ['AWS Lambda', 'Amazon EC2', 'AWS Fargate', 'Amazon EBS'],
            correctAnswers: {0, 2},
            difficulty: 3,
            topic: 'Compute',
            tags: ['AWS', 'Serverless'],
            optionExplanations: {
              0: 'Lambda is serverless.',
              2: 'Fargate runs serverless containers.'
            },
          ),
        ],
      );
      await StorageService.saveExam(sampleExam);

      // 3. Save an in-progress session
      await StorageService.saveSession('exam-aws-cloud', {
        'currentIndex': 1,
        'remainingSeconds': 1800,
        'answers': {
          'q1': [0]
        },
        'marked': ['q2'],
      });

      // 4. Save completed performance record for Alice
      final perfRecord = ExamPerformance(
        examId: 'exam-aws-cloud',
        examName: 'AWS Solutions Architect',
        studentId: studentAlice.id,
        studentName: studentAlice.name,
        date: DateTime(2026, 1, 11),
        totalQuestions: 2,
        correct: 2,
        incorrect: 0,
        unanswered: 0,
        durationSeconds: 320,
      );
      await StorageService.savePerformance(perfRecord);

      // 5. Update user settings
      final settings = await StorageService.loadSettings();
      settings['themeMode'] = 'dark';
      settings['hapticFeedback'] = false;
      settings['defaultDuration'] = 60;
      await StorageService.saveSettings(settings);

      // =========================================================
      // APP TERMINATION: Clear memory and simulate cold boot
      // =========================================================
      final session2Repo = TestStorageRepository(tempTestDir);
      StorageService.setRepository(session2Repo);
      await StorageService.init();

      // =========================================================
      // SESSION 2: Verify ALL data is read intact from disk DB
      // =========================================================
      // 1. Verify students
      final loadedStudents = await StorageService.getAllStudents();
      expect(loadedStudents.length, equals(2));
      expect(
          loadedStudents.any(
              (s) => s.name == 'Alice Johnson' && s.avatarEmoji == '👩‍💻'),
          isTrue);
      expect(
          loadedStudents
              .any((s) => s.name == 'Bob Smith' && s.avatarEmoji == '👨‍🎓'),
          isTrue);

      final activeStudent = await StorageService.getActiveStudent();
      expect(activeStudent, isNotNull);
      expect(activeStudent!.id, equals('student-alice-1'));
      expect(activeStudent.name, equals('Alice Johnson'));

      // 2. Verify exams and questions
      final loadedExams = await StorageService.loadAllExams();
      expect(loadedExams.length, equals(1));
      final loadedExam = loadedExams.first;
      expect(loadedExam.id, equals('exam-aws-cloud'));
      expect(loadedExam.name, equals('AWS Solutions Architect'));
      expect(loadedExam.defaultDuration, equals(45));
      expect(loadedExam.passingPercentage, equals(80));
      expect(loadedExam.questions.length, equals(2));
      expect(loadedExam.questions[0].question,
          equals('What is Amazon S3 primarily used for?'));
      expect(loadedExam.questions[0].correctAnswers, equals({0}));
      expect(loadedExam.questions[1].isMultiple, isTrue);
      expect(loadedExam.questions[1].correctAnswers, equals({0, 2}));

      // 3. Verify in-progress session
      final session = await StorageService.readSession('exam-aws-cloud');
      expect(session, isNotNull);
      expect(session!['currentIndex'], equals(1));
      expect(session['remainingSeconds'], equals(1800));

      // 4. Verify performance history
      final perfs = await StorageService.loadPerformancesForActiveStudent();
      expect(perfs.length, equals(1));
      expect(perfs.first.examName, equals('AWS Solutions Architect'));
      expect(perfs.first.percentage, equals(100.0));
      expect(perfs.first.passed, isTrue);
      expect(perfs.first.studentName, equals('Alice Johnson'));

      // 5. Verify settings
      final loadedSettings = await StorageService.loadSettings();
      expect(loadedSettings['themeMode'], equals('dark'));
      expect(loadedSettings['hapticFeedback'], equals(false));
      expect(loadedSettings['defaultDuration'], equals(60));
      expect(loadedSettings['activeStudentId'], equals('student-alice-1'));
    });

    test(
        'Data modifications, deletions, and profile switching persist across consecutive app restarts',
        () async {
      // Session 1: Create multiple exams & students
      final repo1 = TestStorageRepository(tempTestDir);
      StorageService.setRepository(repo1);
      await StorageService.init();

      final s1 = StudentProfile(id: 's1', name: 'User 1');
      final s2 = StudentProfile(id: 's2', name: 'User 2');
      await StorageService.saveStudent(s1);
      await StorageService.saveStudent(s2);
      await StorageService.setActiveStudent(s2);

      final examA = Exam(id: 'exam-a', name: 'Exam A');
      final examB = Exam(id: 'exam-b', name: 'Exam B');
      await StorageService.saveExam(examA);
      await StorageService.saveExam(examB);

      // Session 2: Delete Exam A and switch active student to User 1
      final repo2 = TestStorageRepository(tempTestDir);
      StorageService.setRepository(repo2);
      await StorageService.init();

      expect((await StorageService.loadAllExams()).length, equals(2));
      await StorageService.deleteExam('exam-a');
      await StorageService.setActiveStudent(s1);

      // Session 3: Cold restart and verify state
      final repo3 = TestStorageRepository(tempTestDir);
      StorageService.setRepository(repo3);
      await StorageService.init();

      final exams = await StorageService.loadAllExams();
      expect(exams.length, equals(1));
      expect(exams.first.id, equals('exam-b'));

      final active = await StorageService.getActiveStudent();
      expect(active?.id, equals('s1'));
      expect(active?.name, equals('User 1'));
    });

    test(
        'Isolated student performance history persists accurately across restarts',
        () async {
      final repo1 = TestStorageRepository(tempTestDir);
      StorageService.setRepository(repo1);
      await StorageService.init();

      final s1 = StudentProfile(id: 's1', name: 'Student One');
      final s2 = StudentProfile(id: 's2', name: 'Student Two');
      await StorageService.saveStudent(s1);
      await StorageService.saveStudent(s2);

      // Performance for s1
      await StorageService.savePerformance(ExamPerformance(
        examId: 'ex1',
        examName: 'Math',
        studentId: 's1',
        studentName: 'Student One',
        correct: 10,
        totalQuestions: 10,
      ));

      // Performance for s2
      await StorageService.savePerformance(ExamPerformance(
        examId: 'ex1',
        examName: 'Math',
        studentId: 's2',
        studentName: 'Student Two',
        correct: 5,
        totalQuestions: 10,
      ));

      // Cold Restart 1: Active student is s1
      final repo2 = TestStorageRepository(tempTestDir);
      StorageService.setRepository(repo2);
      await StorageService.init();
      await StorageService.setActiveStudent(s1);

      final s1Perfs = await StorageService.loadPerformancesForActiveStudent();
      expect(s1Perfs.length, equals(1));
      expect(s1Perfs.first.studentId, equals('s1'));
      expect(s1Perfs.first.correct, equals(10));

      // Switch to s2 and verify isolation
      await StorageService.setActiveStudent(s2);
      final s2Perfs = await StorageService.loadPerformancesForActiveStudent();
      expect(s2Perfs.length, equals(1));
      expect(s2Perfs.first.studentId, equals('s2'));
      expect(s2Perfs.first.correct, equals(5));
    });

    test(
        'Completely deleting an exam purges exam, active session, and performance history',
        () async {
      final repo1 = TestStorageRepository(tempTestDir);
      StorageService.setRepository(repo1);
      await StorageService.init();

      final student = StudentProfile(id: 'std-1', name: 'Student 1');
      await StorageService.saveStudent(student);
      await StorageService.setActiveStudent(student);

      final exam = Exam(id: 'exam-to-purge', name: 'Exam to Purge', questions: [
        Question(
            id: 'q1',
            question: 'Q1',
            options: ['A', 'B', 'C', 'D'],
            correct: 0),
      ]);
      await StorageService.saveExam(exam);

      await StorageService.saveSession('exam-to-purge', {'currentIndex': 0});
      await StorageService.savePerformance(ExamPerformance(
        examId: 'exam-to-purge',
        examName: 'Exam to Purge',
        studentId: 'std-1',
        studentName: 'Student 1',
        correct: 1,
        totalQuestions: 1,
      ));

      expect(
          (await StorageService.loadAllExams())
              .any((e) => e.id == 'exam-to-purge'),
          isTrue);
      expect(await StorageService.readSession('exam-to-purge'), isNotNull);
      expect(
          (await StorageService.loadAllPerformancesAsync())
              .any((p) => p.examId == 'exam-to-purge'),
          isTrue);

      // Perform complete deletion & purge
      await StorageService.deleteExam('exam-to-purge');
      await StorageService.deletePerformancesByExamId('exam-to-purge');

      // Verify cold restart after complete purge
      final repo2 = TestStorageRepository(tempTestDir);
      StorageService.setRepository(repo2);
      await StorageService.init();

      expect(
          (await StorageService.loadAllExams())
              .any((e) => e.id == 'exam-to-purge'),
          isFalse);
      expect(await StorageService.readSession('exam-to-purge'), isNull);
      expect(
          (await StorageService.loadAllPerformancesAsync())
              .any((p) => p.examId == 'exam-to-purge'),
          isFalse);
    });
  });
}
