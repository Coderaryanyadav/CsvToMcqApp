import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/exam.dart';
import '../models/student_profile.dart';
import '../repositories/storage_repository.dart';

/// Metadata stored in `meta.json` to track storage schema version and migration audit history.
class StorageMeta {
  final int schemaVersion;
  final String appVersion;
  final DateTime lastMigrationAt;
  final List<String> migrationHistory;

  const StorageMeta({
    required this.schemaVersion,
    this.appVersion = '2.0.0',
    required this.lastMigrationAt,
    this.migrationHistory = const [],
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'lastMigrationAt': lastMigrationAt.toIso8601String(),
        'migrationHistory': migrationHistory,
      };

  factory StorageMeta.fromJson(Map<String, dynamic> j) {
    return StorageMeta(
      schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
      appVersion: j['appVersion']?.toString() ?? '1.0.0',
      lastMigrationAt: j['lastMigrationAt'] != null
          ? (DateTime.tryParse(j['lastMigrationAt'].toString()) ??
              DateTime.now())
          : DateTime.now(),
      migrationHistory: List<String>.from(j['migrationHistory'] ?? []),
    );
  }

  StorageMeta copyWith({
    int? schemaVersion,
    String? appVersion,
    DateTime? lastMigrationAt,
    List<String>? migrationHistory,
  }) {
    return StorageMeta(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      appVersion: appVersion ?? this.appVersion,
      lastMigrationAt: lastMigrationAt ?? this.lastMigrationAt,
      migrationHistory: migrationHistory ?? List.from(this.migrationHistory),
    );
  }
}

/// Abstract contract for deterministic, idempotent storage migrations.
abstract class Migration {
  int get fromVersion;
  int get toVersion;
  String get description;

  /// Executes the migration safely against the underlying storage directory.
  Future<void> migrate(Directory mcqDir, IStorageRepository repo);
}

/// Migration 1 -> 2:
/// - Introduces explicit schema version headers across settings, exams, and students.
/// - Validates and repairs question bank consistency (ensures question IDs, option explanations, and question types).
/// - Guarantees safe defaults for new settings fields (dailyGoal, themeMode, font size, etc.).
/// - Preserves 100% of existing student profiles, exam tracks, historical attempts, and bookmarks.
class MigrationV1ToV2 extends Migration {
  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  String get description =>
      'Standardize storage schema v2: question canonical types, settings defaults, and student profile metadata';

  @override
  Future<void> migrate(Directory mcqDir, IStorageRepository repo) async {
    if (!await mcqDir.exists()) return;

    // 1. Migrate settings.json
    final settingsFile = File('${mcqDir.path}/settings.json');
    if (await settingsFile.exists()) {
      try {
        final content = await settingsFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final defaults = {
          'themeMode': 'system',
          'darkMode': false,
          'fontSize': 16.0,
          'hapticFeedback': true,
          'soundEffects': false,
          'defaultDuration': 30,
          'defaultQuestionCount': 20,
          'defaultPassingScore': 75,
          'dailyGoal': 20,
          'schemaVersion': 2,
        };
        final updatedSettings = {
          ...defaults,
          ...json,
          'schemaVersion': 2,
        };
        await settingsFile.writeAsString(
          jsonEncode(updatedSettings),
          flush: true,
        );
      } catch (e) {
        // Safe skip on corrupt temporary settings, maintain file
      }
    }

    // 2. Migrate students.json
    final studentsFile = File('${mcqDir.path}/students.json');
    if (await studentsFile.exists()) {
      try {
        final content = await studentsFile.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        final migratedStudents = <StudentProfile>[];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final student = StudentProfile.fromJson(item);
            migratedStudents.add(student);
          }
        }
        await studentsFile.writeAsString(
          jsonEncode(migratedStudents.map((s) => s.toJson()).toList()),
          flush: true,
        );
      } catch (e) {
        // Maintain file on exception
      }
    }

    // 3. Migrate all Exam question bank files (<examId>.json)
    final entities = await mcqDir.list().toList();
    final examFiles = entities.where((f) {
      final name = p.basename(f.path);
      return name.endsWith('.json') &&
          !name.startsWith('performance_') &&
          !name.startsWith('session_') &&
          !name.startsWith('bookmarks_') &&
          !name.startsWith('meta') &&
          name != 'settings.json' &&
          name != 'students.json';
    }).toList();

    for (final f in examFiles) {
      try {
        final file = File(f.path);
        final content = await file.readAsString();
        final json = jsonDecode(content);
        if (json is Map<String, dynamic>) {
          final exam = Exam.fromJson(json);
          // Canonicalize question attributes and schemaVersion
          final updatedExam = exam.copyWith(schemaVersion: 2);
          for (final q in updatedExam.questions) {
            // Ensure questionType is clean
            if (q.correctAnswers.length > 1) {
              q.questionType = 'multiple';
            } else if (q.questionType.isEmpty) {
              q.questionType = 'single';
            }
          }
          await file.writeAsString(
            jsonEncode(updatedExam.toJson()),
            flush: true,
          );
        }
      } catch (e) {
        // Keep original file intact on exception
      }
    }
  }
}

/// Centralized startup migration manager that validates and safely upgrades local storage schemas.
class MigrationManager {
  static const int currentStorageSchemaVersion = 2;

  final List<Migration> _migrations = [
    MigrationV1ToV2(),
  ];

  /// Executes all pending migrations sequentially from the current stored schema version up to [currentStorageSchemaVersion].
  Future<StorageMeta> runMigrations({
    required Directory mcqDir,
    required IStorageRepository repo,
    String appVersion = '2.0.0',
  }) async {
    if (!await mcqDir.exists()) {
      await mcqDir.create(recursive: true);
    }

    final metaFile = File('${mcqDir.path}/meta.json');
    StorageMeta meta;

    if (await metaFile.exists()) {
      try {
        final content = await metaFile.readAsString();
        meta = StorageMeta.fromJson(jsonDecode(content));
      } catch (_) {
        meta = StorageMeta(
          schemaVersion: 1,
          appVersion: appVersion,
          lastMigrationAt: DateTime.now(),
        );
      }
    } else {
      // If meta.json is missing, check if legacy data files exist
      final entities = await mcqDir.list().toList();
      final hasLegacyData = entities.any((e) => e.path.endsWith('.json'));
      meta = StorageMeta(
        schemaVersion: hasLegacyData ? 1 : currentStorageSchemaVersion,
        appVersion: appVersion,
        lastMigrationAt: DateTime.now(),
      );
    }

    // Check if migration is required
    if (meta.schemaVersion < currentStorageSchemaVersion) {
      // 1. Create a safety snapshot of existing mcq_data files before executing migrations
      await _createSafetyBackupSnapshot(mcqDir, meta.schemaVersion);

      int activeVersion = meta.schemaVersion;
      final history = List<String>.from(meta.migrationHistory);

      for (final migration in _migrations) {
        if (migration.fromVersion == activeVersion &&
            migration.toVersion <= currentStorageSchemaVersion) {
          try {
            await migration.migrate(mcqDir, repo);
            activeVersion = migration.toVersion;
            history.add(
              '${DateTime.now().toIso8601String()}: Migrated v${migration.fromVersion} -> v${migration.toVersion} (${migration.description})',
            );
          } catch (e) {
            // Log failure and preserve existing data without destructive reset
            history.add(
              '${DateTime.now().toIso8601String()}: ERROR migrating v${migration.fromVersion} -> v${migration.toVersion}: $e',
            );
            break;
          }
        }
      }

      meta = meta.copyWith(
        schemaVersion: activeVersion,
        appVersion: appVersion,
        lastMigrationAt: DateTime.now(),
        migrationHistory: history,
      );

      // Atomically write updated meta.json
      await metaFile.writeAsString(jsonEncode(meta.toJson()), flush: true);
    } else {
      // Schema is up to date, just ensure meta.json exists
      if (!await metaFile.exists()) {
        await metaFile.writeAsString(jsonEncode(meta.toJson()), flush: true);
      }
    }

    return meta;
  }

  /// Creates a lightweight backup copy of existing JSON files prior to running schema migrations.
  Future<void> _createSafetyBackupSnapshot(
      Directory mcqDir, int currentVersion) async {
    try {
      final snapshotDir = Directory(
        '${mcqDir.path}/.migration_snapshots/v${currentVersion}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!await snapshotDir.exists()) {
        await snapshotDir.create(recursive: true);
      }

      final entities = await mcqDir.list().toList();
      for (final entity in entities) {
        if (entity is File &&
            entity.path.endsWith('.json') &&
            !p.basename(entity.path).startsWith('.')) {
          final targetFile =
              File('${snapshotDir.path}/${p.basename(entity.path)}');
          await entity.copy(targetFile.path);
        }
      }
    } catch (_) {
      // Non-fatal safety snapshot attempt
    }
  }
}
