# 🎓 QuizPro — Modern MCQ & Examination Simulator

A production-ready, cross-platform Flutter application for certification exams, standardized testing, and self-paced question banks (e.g. AWS, CIA, CISA, SQL, and custom curriculums).

Features a multi-student profile system, 100% dynamic database persistence with atomic cold-restart protection, CSV/Excel/JSON import with header alias normalization, timed and untimed exam simulation, instant-feedback practice modes, and comprehensive analytics.

---

## 🚀 Quick Start

### Prerequisites
* **Flutter SDK**: `^3.10.0` or higher
* **Dart SDK**: `^3.0.0 <4.0.0`
* **Xcode / CocoaPods** (for macOS & iOS)
* **Android Studio / Android SDK** (for Android)

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run the App
| Target Platform | Command |
|---|---|
| 🤖 **Android Emulator / Device** | `flutter run -d android` |
| 📱 **iOS Simulator / Device** | `flutter run -d ios` |
| 🍏 **macOS Desktop** | `flutter run -d macos` |

### 3. Static Analysis & Test Verification
```bash
# Verify static analysis (0 errors, 0 warnings, 0 infos)
flutter analyze

# Run full automated test suite (46 unit, widget & database persistence tests)
flutter test
```

### 4. Build Release Packages
```bash
# Android APK
flutter build apk --release

# iOS Release Bundle
flutter build ipa --release

# macOS Application
flutter build macos --release
```

---

## ✨ Core Features & Architecture

### 1. 👥 Multi-Student Onboarding & Profile System
- **Welcome Screen**: Onboarding flow allowing multiple students to create profiles with custom names, emoji avatars, and personalized theme accent colors.
- **Fast Profile Switcher**: 1-tap modal sheet switcher accessible in the top navigation bar and Settings.
- **Data Isolation**: History, exam performance records, scores, and active sessions are isolated per active student profile.

### 2. 💾 100% Dynamic Local Database & Cold-Restart Persistence
- **Zero Mock / Hardcoded Data**: All exams, questions, and performance records are 100% user/import-driven.
- **Atomic Disk Flushing**: All save operations execute with `flush: true` to prevent data loss on sudden app termination or device restart.
- **In-Memory Cache with Write-Through Invalidation**: High-speed RAM caching gives instant $O(1)$/$O(N)$ lookups during navigation while syncing mutations immediately to disk.
- **Collision-Resistant Logging**: Performance records utilize microsecond timestamps and student ID tagging to prevent record collisions during rapid testing.

### 3. 📂 Resilient CSV, Excel (XLSX) & JSON Import Engine
- **Normalized Header Alias Mapping**: Maps flexible headers regardless of casing or formatting (`question`, `question_text`, `prompt`, `option_a`–`option_d`, `choice_1`–`choice_4`, `correct_answer`, `key`, `explanation_a`–`explanation_d`, `topic`, `difficulty`, `tags`).
- **Strict Answer Validation**: Supports letter keys (`A, B, C, D`), number keys (`1, 2, 3, 4`), multi-select (`A|C`, `1|3`), or literal option text.
- **Duplicate & Error Detection**: Checks for empty prompts, intra-file duplicates, and option clashes prior to import.
- **Import Preview Modal**: Full preview of valid items, duplicate warnings, and actionable error suggestions prior to committing changes.

### 4. ⏱️ Responsive Exam Simulation Mode
- **Adaptive Layouts**: Full-screen responsive layout tailored for mobile devices, automatically converting fixed sidebars into bottom-sheet question navigators on small screens.
- **Timed & Untimed Sessions**: Choose preset durations (15m, 30m, 45m, 60m, custom) or untimed study.
- **Timer Expiration Auto-Submit**: Automatically saves, grades, and displays the result breakdown when the countdown timer hits `0:00`.
- **Question Availability Safety Guards**: Prevents starting an exam with more requested questions than exist in the bank.
- **Single & Multi-Select Grading**: Exact set matching for multiple-choice questions.

### 5. 📘 Interactive Practice Mode
- Self-paced question walkthroughs with instant answer verification.
- Revealing per-option explanations (A, B, C, D) and difficulty badges.
- Session time tracking and automatic grading saved to student history upon completion.

### 6. 📈 Chronological Analytics & History
- **True Chronological Ordering**: Evaluates attempts from oldest to newest to compute genuine learning curves.
- **Granular Breakdowns**: Topic-wise and difficulty-wise performance tracking.
- **Zero Fabricated Scores**: Shows "No attempts yet" when no runs have occurred.

---

## 📋 CSV / Excel Import Format Specification

```csv
Question,Option A,Option B,Option C,Option D,Correct Answer,Explanation A,Explanation B,Explanation C,Explanation D,Topic,Difficulty,Tags
"What is Docker?",Container runtime,Operating system,Web browser,Database,A,"Docker manages containers","Not an OS","Not a browser","Not a database",DevOps,2,"containers,virtualization"
"Which are relational databases?",PostgreSQL,MongoDB,MySQL,Redis,A|C,"PostgreSQL is SQL","MongoDB is NoSQL","MySQL is SQL","Redis is Key-Value",Databases,3,"sql,rdbms"
```

---

## 🧪 Test Suite Overview

| Test Suite | File | Description |
|---|---|---|
| **Database Persistence & Cold Restarts** | [`test/database_persistence_test.dart`](test/database_persistence_test.dart) | Multi-session cold restart simulation, data preservation, student isolation, atomic disk writes. |
| **Student Profiles** | [`test/student_profile_test.dart`](test/student_profile_test.dart) | Profile model serialization, color/avatar preservation, student-performance mapping. |
| **Analytics & Chronology** | [`test/analytics_test.dart`](test/analytics_test.dart) | Chronological score improvement, weak topic detection, empty state handling. |
| **CSV & Excel Import** | [`test/import_test.dart`](test/import_test.dart) | Header alias normalization, multi-select delimiters, invalid key handling. |
| **Model Serialization** | [`test/exam_session_test.dart`](test/exam_session_test.dart) | Exam, Question, Performance, and Session JSON round-trips. |
| **Validators** | [`test/validators_test.dart`](test/validators_test.dart) | Question, Exam, and Session parameter validation rules. |
| **Widget UI Tests** | [`test/widget_test.dart`](test/widget_test.dart) | Screen rendering, navigation tabs, exam simulator controls, practice mode triggers. |

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
