import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/performance.dart';
import 'package:csv_to_mcq_app/models/exam.dart';
import 'package:csv_to_mcq_app/models/question.dart';
import 'package:csv_to_mcq_app/models/student_profile.dart';
import 'package:csv_to_mcq_app/repositories/storage_repository.dart';
import 'package:csv_to_mcq_app/services/streak_service.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempTestDir;

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('roadmap_features_test_');
    final repo = TestStorageRepository(tempTestDir);
    StorageService.setRepository(repo);
    await StorageService.init();
    await StorageService.clearAllData();
  });

  tearDown(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  group('Feature 9: Study Streak & Daily Goal Tracking', () {
    test('Empty performances returns 0 streak and uncompleted goal', () {
      final info = StreakService.calculateStreakInfo([], dailyGoal: 20);
      expect(info.currentStreak, 0);
      expect(info.longestStreak, 0);
      expect(info.todayQuestionsAnswered, 0);
      expect(info.isDailyGoalMet, false);
      expect(info.goalProgress, 0.0);
    });

    test('Practice session today counts towards daily goal and streak', () {
      final today = DateTime.now();
      final List<ExamPerformance> perfs = [
        ExamPerformance(
          examId: 'e1',
          examName: 'Math Test',
          totalQuestions: 15,
          correct: 12,
          date: today,
          durationSeconds: 120,
        ),
        ExamPerformance(
          examId: 'e1',
          examName: 'Math Test',
          totalQuestions: 10,
          correct: 8,
          date: today,
          durationSeconds: 90,
        ),
      ];

      final info = StreakService.calculateStreakInfo(perfs, dailyGoal: 20);
      expect(info.currentStreak, 1);
      expect(info.studiedToday, true);
      expect(info.todayQuestionsAnswered, 25);
      expect(info.isDailyGoalMet, true);
      expect(info.goalProgress, 1.0);
    });

    test('Consecutive multi-day practice increments streak correctly', () {
      final now = DateTime.now();
      final day0 = now;
      final day1 = now.subtract(const Duration(days: 1));
      final day2 = now.subtract(const Duration(days: 2));

      final List<ExamPerformance> perfs = [
        ExamPerformance(
          examId: 'e1',
          examName: 'Exam',
          totalQuestions: 10,
          correct: 10,
          date: day0,
          durationSeconds: 100,
        ),
        ExamPerformance(
          examId: 'e1',
          examName: 'Exam',
          totalQuestions: 10,
          correct: 10,
          date: day1,
          durationSeconds: 100,
        ),
        ExamPerformance(
          examId: 'e1',
          examName: 'Exam',
          totalQuestions: 10,
          correct: 10,
          date: day2,
          durationSeconds: 100,
        ),
      ];

      final info = StreakService.calculateStreakInfo(perfs, dailyGoal: 10);
      expect(info.currentStreak, 3);
      expect(info.longestStreak, 3);
      expect(info.studiedToday, true);
    });
  });

  group('Feature 4: Bookmarking & Starred Revision', () {
    test('Toggle bookmarks on and off per student profile', () async {
      final s1 = StudentProfile(id: 's1', name: 'Alice', createdAt: DateTime.now());
      final s2 = StudentProfile(id: 's2', name: 'Bob', createdAt: DateTime.now());

      await StorageService.saveStudent(s1);
      await StorageService.saveStudent(s2);

      // Star Q1 for Alice
      final isStarred1 = await StorageService.toggleBookmark('Q1', studentId: s1.id);
      expect(isStarred1, true);

      // Verify Alice has Q1 bookmarked
      final aliceBookmarks = await StorageService.getBookmarkedQuestionIds(s1.id);
      expect(aliceBookmarks.contains('Q1'), true);

      // Verify Bob has no bookmarks
      final bobBookmarks = await StorageService.getBookmarkedQuestionIds(s2.id);
      expect(bobBookmarks.contains('Q1'), false);

      // Unstar Q1 for Alice
      final isStarred2 = await StorageService.toggleBookmark('Q1', studentId: s1.id);
      expect(isStarred2, false);

      final aliceBookmarksAfter = await StorageService.getBookmarkedQuestionIds(s1.id);
      expect(aliceBookmarksAfter.contains('Q1'), false);
    });
  });

  group('Feature 7: Full Backup & Restore Package', () {
    test('Full data backup package exports and restores accurately', () async {
      final student = StudentProfile(
        id: 'test_student',
        name: 'Alex Developer',
        avatarEmoji: '⚡',
        createdAt: DateTime.now(),
      );
      await StorageService.saveStudent(student);
      await StorageService.setActiveStudent(student);

      final exam = Exam(
        id: 'exam_backup_test',
        name: 'AWS Solutions Architect',
        questions: [
          Question(
            id: 'Q1',
            question: 'What is Amazon S3?',
            options: ['Object storage', 'Relational DB', 'Cache', 'DNS'],
            correctAnswers: {0},
          ),
          Question(
            id: 'Q2',
            question: 'What is Amazon DynamoDB?',
            options: ['NoSQL DB', 'Block storage', 'Queue', 'Server'],
            correctAnswers: {0},
          ),
        ],
      );
      await StorageService.saveExam(exam);

      // Star Q1
      await StorageService.toggleBookmark('Q1', studentId: student.id);

      // Record performance
      final perf = ExamPerformance(
        examId: exam.id,
        examName: exam.name,
        studentId: student.id,
        totalQuestions: 2,
        correct: 2,
        date: DateTime.now(),
        durationSeconds: 45,
      );
      await StorageService.savePerformance(perf);


      // Export full package
      final backup = await StorageService.exportFullBackupData();
      expect(backup['app'], 'QuizPro');
      expect((backup['students'] as List).length, 1);
      expect((backup['exams'] as List).length, 1);
      expect((backup['performances'] as List).length, 1);
      expect(backup['bookmarks'] != null, true);

      // Clear all data
      await StorageService.clearAllData();
      final examsAfterClear = await StorageService.loadAllExams();
      expect(examsAfterClear.isEmpty, true);

      // Restore full package
      await StorageService.restoreFullBackupData(backup);
      final restoredExams = await StorageService.loadAllExams();
      expect(restoredExams.length, 1);
      expect(restoredExams.first.name, 'AWS Solutions Architect');
      expect(restoredExams.first.questions.length, 2);

      final restoredBookmarks = await StorageService.getBookmarkedQuestionIds(student.id);
      expect(restoredBookmarks.contains('Q1'), true);
    });
  });
}
