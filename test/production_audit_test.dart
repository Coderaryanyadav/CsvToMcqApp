import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/exam.dart';
import 'package:csv_to_mcq_app/models/performance.dart';
import 'package:csv_to_mcq_app/models/student_profile.dart';
import 'package:csv_to_mcq_app/services/analytics_service.dart';
import 'package:csv_to_mcq_app/services/storage_service.dart';
import 'package:csv_to_mcq_app/repositories/storage_repository.dart';
import 'package:csv_to_mcq_app/theme/app_theme.dart';

class MockMemoryStorageRepository implements IStorageRepository {
  final Map<String, Exam> _exams = {};
  final List<ExamPerformance> _performances = [];
  final Map<String, StudentProfile> _students = {};
  final Map<String, dynamic> _settings = {};
  final Map<String, Map<String, dynamic>> _sessions = {};
  final Map<String, Set<String>> _bookmarks = {};
  String? _activeStudentId;

  @override
  Future<void> init() async {}

  @override
  Future<void> clearAllData() async {
    _exams.clear();
    _performances.clear();
    _students.clear();
    _sessions.clear();
    _bookmarks.clear();
    _activeStudentId = null;
  }

  @override
  Future<void> deleteExam(String id) async {
    _exams.remove(id);
    _sessions.remove(id);
  }

  @override
  Future<void> deletePerformancesByExamId(String examId) async {
    _performances.removeWhere((p) => p.examId == examId);
  }

  @override
  Future<void> deleteSession(String examId) async {
    _sessions.remove(examId);
  }

  @override
  Future<void> deleteStudent(String id) async {
    _students.remove(id);
    if (_activeStudentId == id) {
      _activeStudentId = _students.isNotEmpty ? _students.keys.first : null;
    }
  }

  @override
  Future<Map<String, dynamic>> exportFullBackupData() async {
    return {
      'exams': _exams.values.map((e) => e.toJson()).toList(),
      'students': _students.values.map((s) => s.toJson()).toList(),
      'performances': _performances.map((p) => p.toJson()).toList(),
    };
  }

  @override
  Future<String?> getActiveStudentId() async => _activeStudentId;

  @override
  Future<List<Exam>> getAllExams() async => _exams.values.toList();

  @override
  Future<List<ExamPerformance>> getAllPerformances() async =>
      List.from(_performances);

  @override
  Future<List<StudentProfile>> getAllStudents() async =>
      _students.values.toList();

  @override
  Future<Set<String>> getBookmarkedQuestionIds(String studentId) async =>
      _bookmarks[studentId] ?? {};

  @override
  Future<Exam?> getExamById(String id) async => _exams[id];

  @override
  Future<Map<String, dynamic>?> getSession(String examId) async =>
      _sessions[examId];

  @override
  Future<Map<String, dynamic>> getSettings() async => Map.from(_settings);

  @override
  Future<StudentProfile?> getStudentById(String id) async => _students[id];

  @override
  Future<bool> isQuestionBookmarked(
          String studentId, String questionId) async =>
      _bookmarks[studentId]?.contains(questionId) ?? false;

  @override
  Future<void> restoreFullBackupData(Map<String, dynamic> data) async {}

  @override
  Future<void> saveExam(Exam exam) async {
    _exams[exam.id] = exam;
  }

  @override
  Future<void> savePerformance(ExamPerformance performance) async {
    _performances.add(performance);
  }

  @override
  Future<void> saveSession(String examId, Map<String, dynamic> session) async {
    _sessions[examId] = session;
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    _settings.addAll(settings);
  }

  @override
  Future<void> saveStudent(StudentProfile student) async {
    _students[student.id] = student;
  }

  @override
  Future<void> setActiveStudentId(String id) async {
    _activeStudentId = id;
  }

  @override
  Future<void> toggleBookmark(String studentId, String questionId) async {
    final set = _bookmarks.putIfAbsent(studentId, () => <String>{});
    if (set.contains(questionId)) {
      set.remove(questionId);
    } else {
      set.add(questionId);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMemoryStorageRepository mockRepo;

  setUp(() async {
    mockRepo = MockMemoryStorageRepository();
    StorageService.setRepository(mockRepo);
  });

  group('P0: Real Dark Mode & AppTheme Tests', () {
    test('AppTheme supports Light and Dark themes with distinct color schemes',
        () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);

      expect(light.scaffoldBackgroundColor, AppTheme.background);
      expect(dark.scaffoldBackgroundColor, AppTheme.darkBackground);
      expect(dark.colorScheme.surface, AppTheme.darkSurface);
    });

    test('ThemeMode setting notifier updates reactively', () {
      AppTheme.setThemeMode('dark');
      expect(AppTheme.themeModeNotifier.value, ThemeMode.dark);

      AppTheme.setThemeMode('light');
      expect(AppTheme.themeModeNotifier.value, ThemeMode.light);

      AppTheme.setThemeMode('system');
      expect(AppTheme.themeModeNotifier.value, ThemeMode.system);
    });
  });

  group('P0: Student Data Isolation Tests', () {
    test('Student A attempts do NOT appear in Student B statistics', () async {
      final studentA = StudentProfile(id: 'student_a', name: 'Alice');
      final studentB = StudentProfile(id: 'student_b', name: 'Bob');

      await StorageService.saveStudent(studentA);
      await StorageService.saveStudent(studentB);

      final perfA1 = ExamPerformance(
        examId: 'exam_1',
        studentId: 'student_a',
        studentName: 'Alice',
        totalQuestions: 10,
        correct: 10,
        incorrect: 0,
        date: DateTime.now().subtract(const Duration(days: 2)),
      );

      final perfA2 = ExamPerformance(
        examId: 'exam_1',
        studentId: 'student_a',
        studentName: 'Alice',
        totalQuestions: 10,
        correct: 8,
        incorrect: 2,
        date: DateTime.now().subtract(const Duration(days: 1)),
      );

      final perfB1 = ExamPerformance(
        examId: 'exam_1',
        studentId: 'student_b',
        studentName: 'Bob',
        totalQuestions: 10,
        correct: 4,
        incorrect: 6,
        date: DateTime.now(),
      );

      await StorageService.savePerformance(perfA1);
      await StorageService.savePerformance(perfA2);
      await StorageService.savePerformance(perfB1);

      // 1. Check Student A's analytics
      await StorageService.setActiveStudent(studentA);
      final perfsA = await StorageService.loadPerformancesForActiveStudent();
      expect(perfsA.length, 2);
      expect(perfsA.every((p) => p.studentId == 'student_a'), isTrue);

      final summaryA = AnalyticsService.calculateSummary(perfsA);
      expect(summaryA.totalAttempts, 2);
      expect(summaryA.totalQuestions, 20);
      expect(summaryA.totalCorrect, 18);
      expect(summaryA.overallAccuracy, 90.0);

      // 2. Check Student B's analytics
      await StorageService.setActiveStudent(studentB);
      final perfsB = await StorageService.loadPerformancesForActiveStudent();
      expect(perfsB.length, 1);
      expect(perfsB.first.studentId, 'student_b');

      final summaryB = AnalyticsService.calculateSummary(perfsB);
      expect(summaryB.totalAttempts, 1);
      expect(summaryB.totalQuestions, 10);
      expect(summaryB.totalCorrect, 4);
      expect(summaryB.overallAccuracy, 40.0);
    });

    test('Analytics calculations with no attempts return strictly 0 values',
        () {
      final summary = AnalyticsService.calculateSummary([]);
      expect(summary.totalAttempts, 0);
      expect(summary.overallAccuracy, 0.0);
      expect(summary.passRate, 0.0);
      expect(summary.totalQuestions, 0);
      expect(summary.totalCorrect, 0);
      expect(summary.scoreTrend, isEmpty);
      expect(summary.weakAreas, isEmpty);
    });
  });

  group('P0: Untimed Exam Modeling & copyWith Tests', () {
    test(
        'Exam duration can transition between timed, untimed (null/0), and custom',
        () {
      final timedExam = Exam(name: 'Math Exam', defaultDuration: 30);
      expect(timedExam.isUntimed, isFalse);
      expect(timedExam.defaultDuration, 30);

      // Transition to untimed via copyWith(defaultDuration: null)
      final untimedExam = timedExam.copyWith(defaultDuration: null);
      expect(untimedExam.isUntimed, isTrue);
      expect(untimedExam.defaultDuration, isNull);

      // Transition to 60 minutes
      final longExam = untimedExam.copyWith(defaultDuration: 60);
      expect(longExam.isUntimed, isFalse);
      expect(longExam.defaultDuration, 60);

      // Serializing and deserializing untimed exam preserves untimed status
      final json = untimedExam.toJson();
      final restored = Exam.fromJson(json);
      expect(restored.isUntimed, isTrue);
      expect(restored.defaultDuration, isNull);
    });
  });

  group('P0: Historical Analytics Snapshot Tests', () {
    test('Performance record stores and restores question snapshots', () {
      final perf = ExamPerformance(
        examId: 'cert_1',
        correct: 1,
        totalQuestions: 1,
        questionSnapshots: {
          'q1': {
            'question': 'What is AWS S3?',
            'topic': 'Storage',
            'difficulty': 1,
            'isCorrect': true,
          }
        },
      );

      final json = perf.toJson();
      final restored = ExamPerformance.fromJson(json);

      expect(restored.questionSnapshots.containsKey('q1'), isTrue);
      expect(restored.questionSnapshots['q1']?['topic'], 'Storage');
      expect(restored.questionSnapshots['q1']?['difficulty'], 1);
    });
  });
}
