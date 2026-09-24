import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/exam.dart';
import 'package:csv_to_mcq_app/models/question.dart';
import 'package:csv_to_mcq_app/models/performance.dart';
import 'package:csv_to_mcq_app/models/student_profile.dart';
import 'package:csv_to_mcq_app/repositories/storage_repository.dart';
import 'package:csv_to_mcq_app/services/storage_service.dart';

class SimulationStorageRepository extends IoStorageRepository {
  final Directory customDir;

  SimulationStorageRepository(this.customDir);

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
    tempTestDir = await Directory.systemTemp
        .createTemp('quizpro_migration_simulation_test_');
  });

  tearDown(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  group('Migration & In-Place Production Upgrade Simulation Tests', () {
    test(
        'Simulate v1 Production Install -> Create Large Dataset -> Upgrade to v2 -> Verify 100% Data Preservation',
        () async {
      final repoV1 = SimulationStorageRepository(tempTestDir);
      await repoV1.init();
      final mcqDir = repoV1.mcqDir;

      // =========================================================================
      // STEP 1: Simulate Legacy v1 Application State
      // =========================================================================
      // 1. Create 2 Student Profiles
      final studentAlice = StudentProfile(
        id: 'student-alice-uuid',
        name: 'Alice Johnson',
        avatarEmoji: '👩‍💻',
        avatarColorValue: 0xFF6366F1,
        createdAt: DateTime(2026, 1, 1),
      );
      final studentBob = StudentProfile(
        id: 'student-bob-uuid',
        name: 'Bob Smith',
        avatarEmoji: '👨‍🎓',
        avatarColorValue: 0xFF10B981,
        createdAt: DateTime(2026, 1, 2),
      );
      final studentsFile = File('${mcqDir.path}/students.json');
      await studentsFile.writeAsString(
        jsonEncode([studentAlice.toJson(), studentBob.toJson()]),
        flush: true,
      );

      // 2. Legacy Settings (without v2 fields like dailyGoal or schemaVersion)
      final settingsFile = File('${mcqDir.path}/settings.json');
      await settingsFile.writeAsString(
        jsonEncode({
          'themeMode': 'dark',
          'fontSize': 18.0,
          'hapticFeedback': true,
          'activeStudentId': studentAlice.id,
        }),
        flush: true,
      );

      // 3. Create 20 distinct Exam Tracks with Questions
      for (int i = 1; i <= 20; i++) {
        final exam = Exam(
          id: 'exam-track-$i',
          name: 'Certification Track #$i',
          category: 'IT & Software',
          passingPercentage: 75,
          defaultDuration: 45,
          schemaVersion: 1, // Legacy v1
          questions: [
            Question(
              id: 'q-track-$i-1',
              question: 'Question 1 for Track $i',
              options: ['Option A', 'Option B', 'Option C', 'Option D'],
              correctAnswers: {0},
              questionType: 'single',
              topic: 'Core Architecture',
              difficulty: 3,
            ),
            Question(
              id: 'q-track-$i-2',
              question: 'Question 2 for Track $i (Multi)',
              options: ['Option A', 'Option B', 'Option C', 'Option D'],
              correctAnswers: {0, 2},
              questionType: 'multiple',
              topic: 'High Availability',
              difficulty: 4,
            ),
          ],
        );
        final examFile = File('${mcqDir.path}/exam-track-$i.json');
        await examFile.writeAsString(jsonEncode(exam.toJson()), flush: true);
      }

      // 4. Create 50 Historical Attempts across both students
      for (int i = 1; i <= 50; i++) {
        final isAlice = i % 2 == 1;
        final studentId = isAlice ? studentAlice.id : studentBob.id;
        final studentName = isAlice ? studentAlice.name : studentBob.name;
        final examNum = (i % 20) + 1;
        final perf = ExamPerformance(
          examId: 'exam-track-$examNum',
          examName: 'Certification Track #$examNum',
          studentId: studentId,
          studentName: studentName,
          date: DateTime(2026, 1, 1).add(Duration(hours: i * 4)),
          totalQuestions: 2,
          correct: i % 3 == 0 ? 1 : 2,
          incorrect: i % 3 == 0 ? 1 : 0,
          durationSeconds: 120 + i,
          questionSnapshots: {
            'q-track-$examNum-1': {
              'question': 'Question 1 for Track $examNum',
              'topic': 'Core Architecture',
              'difficulty': 3,
              'isCorrect': true,
            }
          },
        );
        final perfFile = File(
          '${mcqDir.path}/performance_exam-track-${examNum}_${DateTime.now().microsecondsSinceEpoch}_$i.json',
        );
        await perfFile.writeAsString(jsonEncode(perf.toJson()), flush: true);
      }

      // 5. Bookmarks for Alice and Bob
      final bookmarksAliceFile =
          File('${mcqDir.path}/bookmarks_${studentAlice.id}.json');
      await bookmarksAliceFile.writeAsString(
        jsonEncode(['q-track-1-1', 'q-track-2-2', 'q-track-5-1']),
        flush: true,
      );
      final bookmarksBobFile =
          File('${mcqDir.path}/bookmarks_${studentBob.id}.json');
      await bookmarksBobFile.writeAsString(
        jsonEncode(['q-track-3-1', 'q-track-4-2']),
        flush: true,
      );

      // 6. In-progress session
      final sessionFile = File('${mcqDir.path}/session_exam-track-1.json');
      await sessionFile.writeAsString(
        jsonEncode({
          'examId': 'exam-track-1',
          'currentIndex': 1,
          'remainingSeconds': 2400,
          'answers': {
            'q-track-1-1': [0]
          },
          'marked': ['q-track-1-2'],
          'selectedQuestionTypes': ['single', 'multiple'],
          'isAllQuestionTypes': false,
          'shuffleQuestions': true,
        }),
        flush: true,
      );

      // =========================================================================
      // STEP 2: SIMULATE APP UPGRADE (v1 -> v2)
      // Boot up the updated application with StorageService & MigrationManager
      // =========================================================================
      final repoV2 = SimulationStorageRepository(tempTestDir);
      StorageService.setRepository(repoV2);
      await StorageService.init();

      // =========================================================================
      // STEP 3: VERIFY COMPLETE DATA PRESERVATION & SCHEMA UPGRADE
      // =========================================================================
      // 1. Verify Storage Metadata & Schema Version
      final meta = await StorageService.getStorageMetadata();
      expect(meta, isNotNull);
      expect(meta!.schemaVersion, equals(2));
      expect(await StorageService.getStorageSchemaVersion(), equals(2));
      expect(meta.migrationHistory.length, greaterThanOrEqualTo(1));

      // 2. Verify Safety Snapshot was created
      final snapshotDir = Directory('${mcqDir.path}/.migration_snapshots');
      expect(await snapshotDir.exists(), isTrue);
      final snapshots = await snapshotDir.list().toList();
      expect(snapshots.isNotEmpty, isTrue);

      // 3. Verify All Student Profiles
      final students = await StorageService.getAllStudents();
      expect(students.length, equals(2));
      expect(
          students
              .any((s) => s.id == studentAlice.id && s.name == 'Alice Johnson'),
          isTrue);
      expect(
          students.any((s) => s.id == studentBob.id && s.name == 'Bob Smith'),
          isTrue);

      final activeStudent = await StorageService.getActiveStudent();
      expect(activeStudent, isNotNull);
      expect(activeStudent!.id, equals(studentAlice.id));
      expect(activeStudent.name, equals('Alice Johnson'));

      // 4. Verify All 20 Exams & Upgraded Schema Version
      final exams = await StorageService.loadAllExams();
      expect(exams.length, equals(20));
      for (final exam in exams) {
        expect(exam.schemaVersion, equals(2));
        expect(exam.questions.length, equals(2));
        expect(exam.questions[0].questionType, equals('single'));
        expect(exam.questions[1].questionType, equals('multiple'));
      }

      // 5. Verify All 50 Historical Attempts
      final allPerfs = await StorageService.loadAllPerformancesAsync();
      expect(allPerfs.length, equals(50));

      final alicePerfs =
          await StorageService.loadPerformancesForActiveStudent();
      expect(alicePerfs.length, equals(25));
      expect(alicePerfs.every((p) => p.studentId == studentAlice.id), isTrue);

      // 6. Verify Bookmarks
      final aliceBookmarks =
          await StorageService.getBookmarkedQuestionIds(studentAlice.id);
      expect(aliceBookmarks.length, equals(3));
      expect(aliceBookmarks.contains('q-track-1-1'), isTrue);
      expect(aliceBookmarks.contains('q-track-5-1'), isTrue);

      final bobBookmarks =
          await StorageService.getBookmarkedQuestionIds(studentBob.id);
      expect(bobBookmarks.length, equals(2));
      expect(bobBookmarks.contains('q-track-3-1'), isTrue);

      // 7. Verify Settings with safe defaults applied
      final settings = await StorageService.loadSettings();
      expect(settings['themeMode'], equals('dark')); // Preserved
      expect(settings['fontSize'], equals(18.0)); // Preserved
      expect(settings['dailyGoal'], equals(20)); // Safe default applied
      expect(
          settings['defaultPassingScore'], equals(75)); // Safe default applied
      expect(settings['schemaVersion'], equals(2));

      // 8. Verify Active Session State with Question Type filters
      final session = await StorageService.readSession('exam-track-1');
      expect(session, isNotNull);
      expect(session!['currentIndex'], equals(1));
      expect(session['selectedQuestionTypes'], equals(['single', 'multiple']));
      expect(session['isAllQuestionTypes'], isFalse);
      expect(session['shuffleQuestions'], isTrue);

      // =========================================================================
      // STEP 4: VERIFY IDEMPOTENCY (Consecutive App Launches)
      // =========================================================================
      final repoV2Restart = SimulationStorageRepository(tempTestDir);
      StorageService.setRepository(repoV2Restart);
      await StorageService.init();

      expect(await StorageService.getStorageSchemaVersion(), equals(2));
      expect((await StorageService.getAllStudents()).length, equals(2));
      expect((await StorageService.loadAllExams()).length, equals(20));
      expect(
          (await StorageService.loadAllPerformancesAsync()).length, equals(50));
    });
  });
}
