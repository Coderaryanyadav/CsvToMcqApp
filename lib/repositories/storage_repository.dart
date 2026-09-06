import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/exam.dart';
import '../models/performance.dart';

abstract class IStorageRepository {
  Future<void> init();
  Future<List<Exam>> getAllExams();
  Future<Exam?> getExamById(String id);
  Future<void> saveExam(Exam exam);
  Future<void> deleteExam(String id);
  Future<List<ExamPerformance>> getAllPerformances();
  Future<void> savePerformance(ExamPerformance performance);
  Future<Map<String, dynamic>?> getSession(String examId);
  Future<void> saveSession(String examId, Map<String, dynamic> session);
  Future<void> deleteSession(String examId);
  Future<Map<String, dynamic>> getSettings();
  Future<void> saveSettings(Map<String, dynamic> settings);
  Future<void> clearAllData();
}

class IoStorageRepository implements IStorageRepository {
  late Directory appDir;
  late Directory mcqDir;
  late Directory tempDir;
  bool _initialized = false;

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

  @override
  Future<List<Exam>> getAllExams() async {
    await init();
    final List<Exam> exams = [];
    final files = mcqDir
        .listSync()
        .where((f) =>
            f.path.endsWith('.json') &&
            !f.path.contains('performance_') &&
            !f.path.contains('session_') &&
            !f.path.endsWith('settings.json'))
        .toList();

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
    return exams;
  }

  @override
  Future<Exam?> getExamById(String id) async {
    await init();
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
    final file = File('${mcqDir.path}/${exam.id}.json');
    await file.writeAsString(jsonEncode(exam.toJson()));
  }

  @override
  Future<void> deleteExam(String id) async {
    await init();
    final file = File('${mcqDir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
    await deleteSession(id);
  }

  @override
  Future<List<ExamPerformance>> getAllPerformances() async {
    await init();
    final files = mcqDir
        .listSync()
        .where(
            (f) => f.path.contains('performance_') && f.path.endsWith('.json'))
        .toList();

    final List<ExamPerformance> list = [];
    for (final f in files) {
      try {
        final text = await File(f.path).readAsString();
        list.add(ExamPerformance.fromJson(jsonDecode(text)));
      } catch (_) {}
    }
    // Newest first
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<void> savePerformance(ExamPerformance performance) async {
    await init();
    final file = File(
      '${mcqDir.path}/performance_${performance.examId}_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(jsonEncode(performance.toJson()));
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
    await file.writeAsString(jsonEncode(session));
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
    final file = File('${mcqDir.path}/settings.json');
    if (!await file.exists()) {
      return _defaultSettings();
    }
    try {
      final text = await file.readAsString();
      final json = jsonDecode(text) as Map<String, dynamic>;
      return {
        ..._defaultSettings(),
        ...json,
      };
    } catch (_) {
      return _defaultSettings();
    }
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await init();
    final file = File('${mcqDir.path}/settings.json');
    await file.writeAsString(jsonEncode(settings));
  }

  @override
  Future<void> clearAllData() async {
    await init();
    if (await mcqDir.exists()) {
      final list = mcqDir.listSync();
      for (final f in list) {
        try {
          if (f is File && !f.path.endsWith('settings.json')) {
            await f.delete();
          }
        } catch (_) {}
      }
    }
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
