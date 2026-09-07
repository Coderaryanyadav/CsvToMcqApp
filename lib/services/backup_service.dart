import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';

class BackupRestoreResult {
  final bool success;
  final String message;
  final int studentsRestored;
  final int examsRestored;
  final int performancesRestored;
  final int bookmarksRestored;

  BackupRestoreResult({
    required this.success,
    required this.message,
    this.studentsRestored = 0,
    this.examsRestored = 0,
    this.performancesRestored = 0,
    this.bookmarksRestored = 0,
  });
}

class BackupService {
  static Future<String?> exportBackupToFile() async {
    final data = await StorageService.exportFullBackupData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'QuizPro_Full_Backup_$timestamp.json';

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr, flush: true);
    return file.path;
  }

  static Future<BackupRestoreResult> pickAndRestoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return BackupRestoreResult(
        success: false,
        message: 'No file selected.',
      );
    }

    final file = result.files.single;
    final bytes = file.bytes ??
        (file.path != null ? File(file.path!).readAsBytesSync() : <int>[]);

    if (bytes.isEmpty) {
      return BackupRestoreResult(
        success: false,
        message: 'The selected backup file is empty.',
      );
    }

    try {
      final text = utf8.decode(bytes);
      final dynamic decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return BackupRestoreResult(
          success: false,
          message: 'Invalid backup file format.',
        );
      }

      final data = decoded;
      final int students = (data['students'] as List<dynamic>?)?.length ?? 0;
      final int exams = (data['exams'] as List<dynamic>?)?.length ?? 0;
      final int perfs = (data['performances'] as List<dynamic>?)?.length ?? 0;
      final bookmarksMap = data['bookmarks'] as Map<String, dynamic>?;
      int bookmarksCount = 0;
      if (bookmarksMap != null) {
        for (var list in bookmarksMap.values) {
          if (list is List) bookmarksCount += list.length;
        }
      }

      await StorageService.restoreFullBackupData(data);

      return BackupRestoreResult(
        success: true,
        message: 'Backup successfully restored!',
        studentsRestored: students,
        examsRestored: exams,
        performancesRestored: perfs,
        bookmarksRestored: bookmarksCount,
      );
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        message: 'Failed to restore backup: $e',
      );
    }
  }
}
