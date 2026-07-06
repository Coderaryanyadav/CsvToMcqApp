import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/performance.dart';

class StorageService {
  static late Directory appDir;
  static late Directory mcqDir;
  static late Directory tempDir;

  static Future<void> init() async {
    appDir = await getApplicationDocumentsDirectory();
    tempDir = await getTemporaryDirectory();
    mcqDir = Directory('${appDir.path}/mcq_data');
    if (!mcqDir.existsSync()) {
      mcqDir.createSync(recursive: true);
    }
    // Do not copy bundled sample exams; keep user's storage clean
  }

  static Future<Directory> getDownloadsDirectory() async {
    try {
      final downloads = await getApplicationDocumentsDirectory();
      return downloads;
    } catch (e) {
      return appDir;
    }
  }

  // removed sample exam copying

  static List<FileSystemEntity> listExamFiles() {
    return mcqDir
        .listSync()
        .where((f) =>
            f.path.endsWith('.json') &&
            !f.path.contains('performance_') &&
            !f.path.contains('session_'))
        .toList();
  }

  static Future<void> saveExamFile(
      String filename, Map<String, dynamic> json) async {
    final file = File('${mcqDir.path}/$filename');
    await file.writeAsString(jsonEncode(json));
  }

  static Future<Map<String, dynamic>> readExamFile(String filename) async {
    final file = File('${mcqDir.path}/$filename');
    final text = await file.readAsString();
    return jsonDecode(text);
  }

  static Future<void> deleteExamFile(String filename) async {
    final file = File('${mcqDir.path}/$filename');
    if (file.existsSync()) await file.delete();
  }

  // session save for progress/resume
  static Future<void> saveSession(
      String examId, Map<String, dynamic> session) async {
    final file = File('${mcqDir.path}/session_$examId.json');
    await file.writeAsString(jsonEncode(session));
  }

  static Future<Map<String, dynamic>?> readSession(String examId) async {
    final file = File('${mcqDir.path}/session_$examId.json');
    if (!file.existsSync()) return null;
    final t = await file.readAsString();
    return jsonDecode(t);
  }

  static Future<void> clearSession(String examId) async {
    final file = File('${mcqDir.path}/session_$examId.json');
    if (file.existsSync()) await file.delete();
  }

  // performance tracking
  static Future<void> savePerformance(ExamPerformance performance) async {
    final file = File(
      '${mcqDir.path}/performance_${performance.examId}_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(jsonEncode(performance.toJson()));
  }

  static List<ExamPerformance> loadAllPerformances() {
    final files = mcqDir
        .listSync()
        .where(
            (f) => f.path.contains('performance_') && f.path.endsWith('.json'))
        .toList();
    final List<ExamPerformance> performances = [];
    for (var f in files) {
      try {
        final text = File(f.path).readAsStringSync();
        performances.add(ExamPerformance.fromJson(jsonDecode(text)));
      } catch (e) {
        // ignore
      }
    }
    performances.sort((a, b) => b.date.compareTo(a.date));
    return performances;
  }

  static List<ExamPerformance> getPerformancesForExam(String examId) {
    return loadAllPerformances().where((p) => p.examId == examId).toList();
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final file = File('${mcqDir.path}/settings.json');
    await file.writeAsString(jsonEncode(settings));
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final file = File('${mcqDir.path}/settings.json');
    if (!file.existsSync()) {
      return {
        'darkMode': false,
        'fontSize': 16.0,
        'hapticFeedback': true,
        'soundEffects': false,
      };
    }
    try {
      return jsonDecode(await file.readAsString());
    } catch (e) {
      return {
        'darkMode': false,
        'fontSize': 16.0,
        'hapticFeedback': true,
        'soundEffects': false,
      };
    }
  }
}
