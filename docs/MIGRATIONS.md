# QuizPro — Storage Schema & Migrations Guide

## 1. Storage Schema Versioning

QuizPro implements a centralized, deterministic migration pipeline powered by `MigrationManager` (`lib/services/migration_service.dart`).

Current Storage Schema Version: **`2`**

Storage schema version is tracked explicitly in `${mcqDir}/meta.json`:
```json
{
  "schemaVersion": 2,
  "appVersion": "2.0.0",
  "lastMigrationAt": "2026-09-13T14:50:00.000Z",
  "migrationHistory": [
    "2026-09-13T14:50:00.000Z: Migrated v1 -> v2 (Standardize storage schema v2: question canonical types, settings defaults, and student profile metadata)"
  ]
}
```

---

## 2. Startup Migration Workflow

When the application boots:
```
App Launches (main.dart)
       │
       ▼
StorageService.init()
       │
       ▼
MigrationManager.runMigrations()
       │
       ├─► Read meta.json
       ├─► Compare schemaVersion against currentStorageSchemaVersion (2)
       │
       ├─► If schemaVersion < Target:
       │     ├─► Create safety backup snapshot in .migration_snapshots/
       │     ├─► Execute pending migrations sequentially (v1 -> v2)
       │     ├─► Validate migrated data integrity
       │     └─► Update meta.json with new schema version & timestamp
       │
       └─► Continue app startup smoothly
```

---

## 3. Migration Registry

### `MigrationV1ToV2` (v1 → v2)
- **Description**: Standardizes storage schema v2 with canonical question types, explicit schema version headers, safe settings defaults, and student metadata.
- **Actions**:
  1. Updates `settings.json` with safe defaults (`dailyGoal: 20`, `themeMode: 'system'`, `schemaVersion: 2`).
  2. Verifies student profiles in `students.json`.
  3. Canonicalizes question types (`single`, `multiple`, `true_false`) across all `<examId>.json` files and sets `schemaVersion: 2`.
  4. Preserves 100% of user data, attempts, and bookmarks.

---

## 4. Safety & Failure Protection Guarantees

1. **Pre-Migration Safety Snapshot**:  
   Before running any migration, `MigrationManager` copies existing JSON files to `.migration_snapshots/v<version>_<timestamp>/`.
2. **Deterministic & Idempotent**:  
   Running a migration multiple times produces the identical safe result without duplicate records.
3. **Non-Destructive Error Handling**:  
   If an unexpected file system exception occurs during a migration, the engine logs the error to `meta.json` and preserves all existing user records rather than resetting the database.

---

## 5. Future Update Engineering Contract

For any future release modifying stored data structures:
1. Increment `MigrationManager.currentStorageSchemaVersion`.
2. Implement a new concrete `Migration` subclass (e.g. `MigrationV2ToV3`).
3. Add the migration to `MigrationManager._migrations`.
4. Ensure the migration provides safe defaults for existing users.
5. Write an automated upgrade test in `test/migration_upgrade_simulation_test.dart`.
