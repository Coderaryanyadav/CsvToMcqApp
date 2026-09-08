import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/exam.dart';
import '../models/performance.dart';
import '../models/student_profile.dart';

abstract class IStorageRepository {
  Future<void> init();
  Future<List<Exam>> getAllExams();
  Future<Exam?> getExamById(String id);
  Future<void> saveExam(Exam exam);
  Future<void> deleteExam(String id);
  Future<List<ExamPerformance>> getAllPerformances();
  Future<void> savePerformance(ExamPerformance performance);
  Future<void> deletePerformancesByExamId(String examId);
  Future<Map<String, dynamic>?> getSession(String examId);
  Future<void> saveSession(String examId, Map<String, dynamic> session);
  Future<void> deleteSession(String examId);
  Future<Map<String, dynamic>> getSettings();
  Future<void> saveSettings(Map<String, dynamic> settings);
  Future<void> clearAllData();

  // Student Profiles
  Future<List<StudentProfile>> getAllStudents();
  Future<StudentProfile?> getStudentById(String id);
  Future<void> saveStudent(StudentProfile student);
  Future<void> deleteStudent(String id);
  Future<String?> getActiveStudentId();
  Future<void> setActiveStudentId(String id);

  // Bookmarks
  Future<Set<String>> getBookmarkedQuestionIds(String studentId);
  Future<void> toggleBookmark(String studentId, String questionId);
  Future<bool> isQuestionBookmarked(String studentId, String questionId);

  // Full Backup & Restore
  Future<Map<String, dynamic>> exportFullBackupData();
  Future<void> restoreFullBackupData(Map<String, dynamic> data);
}

class IoStorageRepository implements IStorageRepository {
  late Directory appDir;
  late Directory mcqDir;
  late Directory tempDir;
  bool _initialized = false;

  // In-memory caches for maximum performance
  List<Exam>? _cachedExams;
  List<ExamPerformance>? _cachedPerformances;
  List<StudentProfile>? _cachedStudents;
  Map<String, dynamic>? _cachedSettings;
  final Map<String, Set<String>> _cachedBookmarks = {};

  @override
  Future<void> init() async {
    if (_initialized) return;
    appDir = await getApplicationDocumentsDirectory();
    tempDir = await getTemporaryDirectory();
    mcqDir = Directory('${appDir.path}/mcq_data');
    if (!await mcqDir.exists()) {
      await mcqDir.create(recursive: true);
    }
    _initialized = true;
  }

  /// True atomic file writing helper: writes to a temporary file, flushes to disk,
  /// and atomically renames to the target path.
  Future<void> _writeAtomic(File file, String content) async {
    final tempFile =
        File('${file.path}.tmp_${DateTime.now().microsecondsSinceEpoch}');
    try {
      await tempFile.writeAsString(content, flush: true);
      await tempFile.rename(file.path);
    } catch (_) {
      // Fallback for file systems or platforms where atomic rename is restricted
      try {
        await file.writeAsString(content, flush: true);
      } finally {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<Set<String>> getBookmarkedQuestionIds(String studentId) async {
    await init();
    if (_cachedBookmarks.containsKey(studentId)) {
      return Set<String>.from(_cachedBookmarks[studentId]!);
    }
    final file = File('${mcqDir.path}/bookmarks_$studentId.json');
    if (!await file.exists()) {
      _cachedBookmarks[studentId] = <String>{};
      return <String>{};
    }
    try {
      final text = await file.readAsString();
      final list = jsonDecode(text) as List<dynamic>;
      final set = list.map((e) => e.toString()).toSet();
      _cachedBookmarks[studentId] = set;
      return Set<String>.from(set);
    } catch (_) {
      _cachedBookmarks[studentId] = <String>{};
      return <String>{};
    }
  }

  @override
  Future<void> toggleBookmark(String studentId, String questionId) async {
    await init();
    final bookmarks = await getBookmarkedQuestionIds(studentId);
    if (bookmarks.contains(questionId)) {
      bookmarks.remove(questionId);
    } else {
      bookmarks.add(questionId);
    }
    _cachedBookmarks[studentId] = bookmarks;
    final file = File('${mcqDir.path}/bookmarks_$studentId.json');
    await _writeAtomic(file, jsonEncode(bookmarks.toList()));
  }

  @override
  Future<bool> isQuestionBookmarked(String studentId, String questionId) async {
    final bookmarks = await getBookmarkedQuestionIds(studentId);
    return bookmarks.contains(questionId);
  }

  @override
  Future<Map<String, dynamic>> exportFullBackupData() async {
    await init();
    final exams = await getAllExams();
    final students = await getAllStudents();
    final perfs = await getAllPerformances();
    final settings = await getSettings();
    final activeStudentId = await getActiveStudentId();

    final Map<String, List<String>> bookmarksMap = {};
    for (final s in students) {
      final b = await getBookmarkedQuestionIds(s.id);
      if (b.isNotEmpty) {
        bookmarksMap[s.id] = b.toList();
      }
    }

    return {
      'app': 'QuizPro',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'activeStudentId': activeStudentId,
      'settings': settings,
      'students': students.map((s) => s.toJson()).toList(),
      'exams': exams.map((e) => e.toJson()).toList(),
      'performances': perfs.map((p) => p.toJson()).toList(),
      'bookmarks': bookmarksMap,
    };
  }

  @override
  Future<void> restoreFullBackupData(Map<String, dynamic> data) async {
    await init();
    if (data['students'] != null) {
      final list = (data['students'] as List<dynamic>)
          .map((s) => StudentProfile.fromJson(s as Map<String, dynamic>))
          .toList();
      for (final s in list) {
        await saveStudent(s);
      }
    }

    if (data['settings'] != null) {
      await saveSettings(Map<String, dynamic>.from(data['settings'] as Map));
    }

    if (data['activeStudentId'] != null) {
      await setActiveStudentId(data['activeStudentId'].toString());
    }

    if (data['exams'] != null) {
      final list = (data['exams'] as List<dynamic>)
          .map((e) => Exam.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final e in list) {
        await saveExam(e);
      }
    }

    if (data['performances'] != null) {
      final list = (data['performances'] as List<dynamic>)
          .map((p) => ExamPerformance.fromJson(p as Map<String, dynamic>))
          .toList();
      for (final p in list) {
        await savePerformance(p);
      }
    }

    if (data['bookmarks'] != null) {
      final map = data['bookmarks'] as Map<String, dynamic>;
      for (final entry in map.entries) {
        final studentId = entry.key;
        final list =
            (entry.value as List<dynamic>).map((e) => e.toString()).toSet();
        _cachedBookmarks[studentId] = list;
        final file = File('${mcqDir.path}/bookmarks_$studentId.json');
        await _writeAtomic(file, jsonEncode(list.toList()));
      }
    }

    // Invalidate caches to ensure clean fresh reload
    _cachedExams = null;
    _cachedPerformances = null;
    _cachedStudents = null;
    _cachedSettings = null;
  }

  @override
  Future<List<Exam>> getAllExams() async {
    await init();
    if (_cachedExams != null) {
      return List<Exam>.from(_cachedExams!);
    }

    final List<Exam> exams = [];
    final entities = await mcqDir.list().toList();
    final files = entities.where((f) {
      final filename = p.basename(f.path);
      return filename.endsWith('.json') &&
          !filename.startsWith('performance_') &&
          !filename.startsWith('session_') &&
          !filename.startsWith('bookmarks_') &&
          filename != 'settings.json' &&
          filename != 'students.json';
    }).toList();

    for (final f in files) {
      try {
        final content = await File(f.path).readAsString();
        final json = jsonDecode(content);
        if (json is Map<String, dynamic>) {
          exams.add(Exam.fromJson(json));
        }
      } catch (_) {
        // Skip malformed files gracefully
      }
    }
    exams.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _cachedExams = exams;
    return List<Exam>.from(exams);
  }

  @override
  Future<Exam?> getExamById(String id) async {
    await init();
    if (_cachedExams != null) {
      final match = _cachedExams!.where((e) => e.id == id);
      if (match.isNotEmpty) return match.first;
    }

    final file = File('${mcqDir.path}/$id.json');
    if (!await file.exists()) return null;
    try {
      final text = await file.readAsString();
      return Exam.fromJson(jsonDecode(text));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveExam(Exam exam) async {
    await init();
    exam.reindexQuestions();

    if (_cachedExams != null) {
      final index = _cachedExams!.indexWhere((e) => e.id == exam.id);
      if (index >= 0) {
        _cachedExams![index] = exam;
      } else {
        _cachedExams!.insert(0, exam);
      }
      _cachedExams!.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    final file = File('${mcqDir.path}/${exam.id}.json');
    await _writeAtomic(file, jsonEncode(exam.toJson()));
  }

  @override
  Future<void> deleteExam(String id) async {
    await init();
    _cachedExams?.removeWhere((e) => e.id == id);

    final file = File('${mcqDir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
    await deleteSession(id);
  }

  @override
  Future<List<ExamPerformance>> getAllPerformances() async {
    await init();
    if (_cachedPerformances != null) {
      return List<ExamPerformance>.from(_cachedPerformances!);
    }

    final entities = await mcqDir.list().toList();
    final files = entities.where((f) {
      final name = p.basename(f.path);
      return name.startsWith('performance_') && name.endsWith('.json');
    }).toList();

    final List<ExamPerformance> list = [];
    for (final f in files) {
      try {
        final text = await File(f.path).readAsString();
        list.add(ExamPerformance.fromJson(jsonDecode(text)));
      } catch (_) {}
    }
    // Newest first
    list.sort((a, b) => b.date.compareTo(a.date));
    _cachedPerformances = list;
    return List<ExamPerformance>.from(list);
  }

  @override
  Future<void> savePerformance(ExamPerformance performance) async {
    await init();
    if (_cachedPerformances != null) {
      _cachedPerformances!.insert(0, performance);
      _cachedPerformances!.sort((a, b) => b.date.compareTo(a.date));
    }

    final studentTag =
        performance.studentId != null ? '_${performance.studentId}' : '';
    final file = File(
      '${mcqDir.path}/performance_${performance.examId}_${DateTime.now().microsecondsSinceEpoch}$studentTag.json',
    );
    await _writeAtomic(file, jsonEncode(performance.toJson()));
  }

  @override
  Future<void> deletePerformancesByExamId(String examId) async {
    await init();
    _cachedPerformances?.removeWhere((p) => p.examId == examId);

    final entities = await mcqDir.list().toList();
    final files = entities.where((f) {
      final name = p.basename(f.path);
      return name.startsWith('performance_${examId}_') &&
          name.endsWith('.json');
    }).toList();

    for (final f in files) {
      try {
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
  }

  @override
  Future<Map<String, dynamic>?> getSession(String examId) async {
    await init();
    final file = File('${mcqDir.path}/session_$examId.json');
    if (!await file.exists()) return null;
    try {
      final text = await file.readAsString();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSession(String examId, Map<String, dynamic> session) async {
    await init();
    final file = File('${mcqDir.path}/session_$examId.json');
    await _writeAtomic(file, jsonEncode(session));
  }

  @override
  Future<void> deleteSession(String examId) async {
    await init();
    final file = File('${mcqDir.path}/session_$examId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    await init();
    if (_cachedSettings != null) {
      return Map<String, dynamic>.from(_cachedSettings!);
    }

    final file = File('${mcqDir.path}/settings.json');
    if (!await file.exists()) {
      final defaults = _defaultSettings();
      _cachedSettings = Map<String, dynamic>.from(defaults);
      return defaults;
    }
    try {
      final text = await file.readAsString();
      final json = jsonDecode(text) as Map<String, dynamic>;
      final merged = {
        ..._defaultSettings(),
        ...json,
      };
      _cachedSettings = Map<String, dynamic>.from(merged);
      return merged;
    } catch (_) {
      final defaults = _defaultSettings();
      _cachedSettings = Map<String, dynamic>.from(defaults);
      return defaults;
    }
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await init();
    _cachedSettings = Map<String, dynamic>.from(settings);
    final file = File('${mcqDir.path}/settings.json');
    await _writeAtomic(file, jsonEncode(settings));
  }

  @override
  Future<void> clearAllData() async {
    await init();
    _cachedExams = null;
    _cachedPerformances = null;
    _cachedStudents = null;
    _cachedSettings = null;
    _cachedBookmarks.clear();

    if (await mcqDir.exists()) {
      final list = await mcqDir.list().toList();
      for (final f in list) {
        try {
          if (f is File && !f.path.endsWith('settings.json')) {
            await f.delete();
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<List<StudentProfile>> getAllStudents() async {
    await init();
    if (_cachedStudents != null) {
      return List<StudentProfile>.from(_cachedStudents!);
    }

    final file = File('${mcqDir.path}/students.json');
    if (!await file.exists()) {
      _cachedStudents = [];
      return [];
    }
    try {
      final text = await file.readAsString();
      final list = jsonDecode(text) as List<dynamic>;
      final students = list
          .map((item) => StudentProfile.fromJson(item as Map<String, dynamic>))
          .toList();
      _cachedStudents = students;
      return List<StudentProfile>.from(students);
    } catch (_) {
      _cachedStudents = [];
      return [];
    }
  }

  @override
  Future<StudentProfile?> getStudentById(String id) async {
    final students = await getAllStudents();
    try {
      return students.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveStudent(StudentProfile student) async {
    await init();
    final students = await getAllStudents();
    final index = students.indexWhere((s) => s.id == student.id);
    if (index >= 0) {
      students[index] = student;
    } else {
      students.add(student);
    }
    _cachedStudents = students;
    final file = File('${mcqDir.path}/students.json');
    await _writeAtomic(
      file,
      jsonEncode(students.map((s) => s.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteStudent(String id) async {
    await init();
    final students = await getAllStudents();
    students.removeWhere((s) => s.id == id);
    _cachedStudents = students;
    final file = File('${mcqDir.path}/students.json');
    await _writeAtomic(
      file,
      jsonEncode(students.map((s) => s.toJson()).toList()),
    );

    final activeId = await getActiveStudentId();
    if (activeId == id) {
      if (students.isNotEmpty) {
        await setActiveStudentId(students.first.id);
      } else {
        final settings = await getSettings();
        settings.remove('activeStudentId');
        await saveSettings(settings);
      }
    }
  }

  @override
  Future<String?> getActiveStudentId() async {
    final settings = await getSettings();
    return settings['activeStudentId'] as String?;
  }

  @override
  Future<void> setActiveStudentId(String id) async {
    final settings = await getSettings();
    settings['activeStudentId'] = id;
    await saveSettings(settings);
  }

  Map<String, dynamic> _defaultSettings() => {
        'themeMode': 'system', // system | light | dark
        'darkMode': false,
        'fontSize': 16.0,
        'hapticFeedback': true,
        'soundEffects': false,
        'defaultDuration': 30,
        'defaultQuestionCount': 20,
        'defaultPassingScore': 75,
      };
}
