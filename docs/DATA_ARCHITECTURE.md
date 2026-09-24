# QuizPro — Data Architecture & Persistence Blueprint

## 1. Architectural Overview

QuizPro employs a **Service-Repository Document Architecture** utilizing cross-platform atomic JSON document storage.

### Core Tenet
> **App Update ≠ Data Reset**  
> Every update must preserve 100% of user profiles, learning statistics, practice and exam history, bookmarks, and user preferences.

```
+-------------------------------------------------------------------------+
|                              FLUTTER UI                                 |
|  HomeScreen | TakeExamScreen | PracticeModeScreen | StatisticsScreen    |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
|                            SERVICE LAYER                                |
|  StorageService | QuestionSelectionService | StreakService | Analytics  |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
|                         MIGRATION MANAGER                               |
|  Tracks schemaVersion in meta.json, validates & upgrades storage safely |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
|                        STORAGE REPOSITORY                               |
|  IStorageRepository -> IoStorageRepository (Atomic file I/O & flush)    |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
|                    LOCAL PERSISTENCE (mcq_data/)                        |
|  - meta.json             (Storage schema version & migration history)   |
|  - students.json         (Multi-user student profiles)                  |
|  - settings.json         (Preferences, active student ID, defaults)     |
|  - <examId>.json         (Question banks, options, explanations)        |
|  - performance_*.json    (Immutable exam attempts with snapshots)       |
|  - session_<examId>.json (In-progress resumable exam state)             |
|  - bookmarks_*.json      (Student bookmarked question IDs)              |
+-------------------------------------------------------------------------+
```

---

## 2. Persistent Storage Directory & Atomic File IO

All persistent data is stored inside:
`${getApplicationDocumentsDirectory()}/mcq_data/`

### Atomic File Write Guarantee
To guarantee that sudden app termination, power interruption, or operating system kills never corrupt a file:
1. Data is written to a temporary file: `${file.path}.tmp_${microseconds}`.
2. File contents are flushed immediately to physical disk (`flush: true`).
3. The temporary file is atomically renamed to the target file.

---

## 3. Data Classification & Lifecycle Matrix

| Data Entity | File Path | Owner | Lifecycle & Update Guarantee |
|---|---|---|---|
| **Storage Metadata** | `meta.json` | System | Tracks database schema version, app version, migration audit log. Preserved across all updates. |
| **Student Profiles** | `students.json` | User | Contains all user accounts (`id`, `name`, `avatarEmoji`, `avatarColorValue`). Never reset. |
| **Settings & Active State** | `settings.json` | User | Stores app preferences and active student ID pointer. Missing fields receive safe defaults. |
| **Question Banks** | `<examId>.json` | Content/User | Holds exam tracks and question banks with immutable UUIDs. |
| **Exam Performance History** | `performance_<examId>_<timestamp>_<studentId>.json` | User | Immutable completed attempt records with embedded `questionSnapshots`. |
| **Active Session** | `session_<examId>.json` | User | Interrupted exam state, auto-saved every 10 seconds. Recoverable on restart. |
| **Bookmarks** | `bookmarks_<studentId>.json` | User | Starred questions isolated per student profile. |

---

## 4. Separation of Question Content vs. User Data

A critical requirement of QuizPro:
- **Updating the Question Bank** (e.g. importing new questions or fixing typos) does **NOT** alter, wipe, or recalculate completed historical exam records.
- Historical attempts contain frozen `questionSnapshots` capturing the exact question text, options, and user answer at the time of completion.

---

## 5. Offline & Multi-User Isolation

1. **Zero Cloud Dependency**: Operates 100% offline with zero remote telemetry requirements.
2. **Student Data Isolation**: Each student profile has separate performance records, streaks, and bookmarks. Switching student profiles filters history and statistics dynamically without cross-contamination.
