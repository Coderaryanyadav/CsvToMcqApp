# 🎓 QuizPro — Modern MCQ & Examination Platform

A production-quality Flutter application designed for certification exams, standardized tests, and custom learning curricula (e.g. AWS, CIA, CISA, SQL, and custom question banks). Features collision-resistant UUIDs, robust CSV/Excel import with header alias normalization, timed and untimed exam modes, session restore with double-submit guards, true chronological analytics, Material 3 Light and Dark themes, and an automated exam quality audit engine.

---

## 🚀 Quick Start

### Prerequisites
* **Flutter SDK**: `^3.10.0` or higher
* **Dart SDK**: `^3.0.0 <4.0.0`

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run the App
| Target Platform | Command |
|---|---|
| 🍏 **macOS Desktop** | `flutter run -d macos` |
| 📱 **iOS Simulator / Device** | `flutter run -d ios` |
| 🤖 **Android Emulator / Device** | `flutter run -d android` |
| 🐧 **Linux Desktop** | `flutter run -d linux` |
| 🪟 **Windows Desktop** | `flutter run -d windows` |

> **Note on Web Platform**: The application is optimized primarily for desktop (macOS, Windows, Linux) and mobile (iOS, Android). Local file system persistence uses asynchronous JSON repositories. A web abstraction layer is provided via `IStorageRepository`.

### 3. Run Static Analysis & Tests
```bash
# Format code
dart format .

# Static analysis (zero warnings/errors)
flutter analyze

# Run complete test suite (40+ automated unit & widget tests)
flutter test
```

---

## ✨ Core Features

### 1. 📂 Resilient CSV & Excel (XLSX) Import Engine
- **Normalized Header Alias Mapping**: Accurately maps headers regardless of casing, punctuation, or spaces (`question`, `question_text`, `prompt`, `q`, `option_a`, `choice_1`, `correct_answer`, `key`, `explanation_a`..`explanation_d`, `topic`, `difficulty`, `tags`).
- **Strict Answer Validation**: Supports `A, B, C, D`, `1, 2, 3, 4`, multiple select (`A|C`, `1|3`), or exact option text. **Never silently defaults missing or invalid answers to Option A.**
- **Duplicate & Error Detection**: Flags intra-file duplicate questions and intra-question duplicate options before importing.
- **Import Preview Modal**: Full preview of valid items, duplicate warnings, and actionable error suggestions prior to committing changes.
- **Sample Template Download**: Export a clean starter CSV template directly from the Settings screen.

### 2. ⏱️ Exam Taking Mode
- **Timed & Untimed Modes**: Choose from preset durations (15m, 30m, 45m, 60m, custom) or full untimed mode with elapsed timer.
- **Multi-Select & Single-Select**: Full support for single choice (`○`) and multiple choice (`☐`) with exact set match grading.
- **Color-Coded Multi-State Timer**:
  - `> 5 min`: Normal state (Theme primary)
  - `<= 5 min`: Warning state (Amber/Orange)
  - `<= 1 min`: Critical state (Red)
  - `< 10 sec`: Urgent pulsing state
- **Autosave & Session Restore**: Background auto-save protects active attempts. Resume directly with questions, marked items, timer state, and user selections intact.
- **Double-Submit Protection**: Guarded lifecycle prevents duplicate test submissions or race conditions.
- **Desktop Keyboard Shortcuts**:
  - `1 - 4`: Select option A, B, C, or D
  - `← / →`: Previous / Next question
  - `M`: Mark / Bookmark for review
  - `Enter`: Next question
  - `Esc`: Save & Exit prompt

### 3. 📘 Practice Mode & Practice Mistakes Drill
- Instant answer feedback on demand with individual option explanations (A, B, C, D).
- Targeted **"Practice Mistakes"** workflow accessible immediately from the results screen to drill missed questions.

### 4. 📈 True Chronological Analytics
- **Chronological Ordering**: Calculations sort attempts from oldest to newest to ensure positive improvement values represent genuine progress ($RecentAvg - EarlierAvg$).
- **No Fabricated Fallback Scores**: Zero attempts display "Not started" or "No attempts yet" instead of fake percentages.
- **Topic & Difficulty Breakdown**: Granular accuracy tracking across topics and difficulty levels (1–5) with actionable weak area drill triggers.

### 5. 🛡️ Exam Quality Audit Engine
- Automated validation scanning exams across three tiers:
  - **CRITICAL**: Empty prompts, invalid answers, missing options, intra-exam duplicate questions, corrupted records.
  - **WARNING**: Missing explanations, missing topics, uncategorized tags, very long question prompts (>500 chars).
  - **SUGGESTION**: Topic diversity, difficulty distribution balance.
- Generates an objective Data Readiness score (0–100%) with a 1-click editor jump.

### 6. 🎨 Material 3 Light & Dark Themes
- Seamless Light, Dark, and System theme support with centralized semantic color tokens (`AppTheme`).
- Responsive layouts with centered max-width content on large desktop displays and adaptive question navigation.

---

## 📋 CSV / Excel Import Format Specification

You can import `.csv` or `.xlsx` files with any of the following column arrangements:

```csv
Question,Option A,Option B,Option C,Option D,Correct Answer,Explanation A,Explanation B,Explanation C,Explanation D,Topic,Difficulty,Tags
"What is Docker?",Container runtime,Operating system,Web browser,Database,A,"Docker manages containers","Not an OS","Not a browser","Not a database",DevOps,2,"containers,virtualization"
"Which are relational databases?",PostgreSQL,MongoDB,MySQL,Redis,A|C,"PostgreSQL is SQL","MongoDB is NoSQL","MySQL is SQL","Redis is Key-Value",Databases,3,"sql,rdbms"
```

### Supported Header Aliases:
- **Question**: `question`, `question_text`, `question text`, `prompt`, `q`, `item`
- **Option A**: `option_a`, `option a`, `option_1`, `choice_a`, `a`, `opt_a`
- **Option B**: `option_b`, `option b`, `option_2`, `choice_b`, `b`, `opt_b`
- **Option C**: `option_c`, `option c`, `option_3`, `choice_c`, `c`, `opt_c`
- **Option D**: `option_d`, `option d`, `option_4`, `choice_d`, `d`, `opt_d`
- **Correct Answer**: `correct_answer`, `correct answer`, `correct`, `answer`, `key`, `ans`
- **Question Type**: `question_type`, `question type`, `type`, `qtype` (`single` or `multiple`)
- **Explanations**: `explanation_a`..`explanation_d` (or single `explanation` / `rationale`)
- **Metadata**: `topic`, `difficulty` (1 to 5), `tags`

---

## 🏛️ Architecture & Storage

```text
UI (Screens & Widgets)
       ↓
Services & Controllers (AnalyticsService, ImportService)
       ↓
Repositories (IStorageRepository)
       ↓
Storage Engines (IoStorageRepository / Platform Abstraction)
```

- **UUID Question IDs**: Question models use collision-resistant UUIDs internally, with clean `displayNumber` / `displayId` (e.g. `Q1`, `Q2`) for student-facing UI.
- **Schema Versioning**: Exam data includes `"schemaVersion": 1` allowing safe forwards/backwards migrations.
- **Privacy Notice**: All exam questions, user answers, and performance metrics are stored locally by the application on your device and are not uploaded to external servers.

---

## 🧪 Testing

The repository maintains an automated test suite across all critical domains:

```bash
flutter test
```

### Test Coverage Highlights:
- **Import Tests (`test/import_test.dart`)**: Header alias normalization, numeric answers (`1|3`), multi-select answer parsing, exact text matching, duplicate rejection, and strict rejection of missing correct answers (no fallback to A).
- **Analytics Tests (`test/analytics_test.dart`)**: Chronological trend validation, positive/negative improvement sign correctness, topic breakdowns, weak area detection, and zero fabricated stats on empty states.
- **Validators Tests (`test/validators_test.dart`)**: Validation rules for `QuestionValidator`, `ExamValidator`, and `SessionValidator`.
- **Exam Model & Session Tests (`test/exam_session_test.dart`)**: Schema versioning, custom passing threshold evaluation, and sequential question reindexing.
- **Widget Tests (`test/widget_test.dart`)**: Exam navigation, option selection, practice mode answer toggle, and initial loading state.

---

## 📄 License

MIT License. Developed with ❤️ for educators, certification candidates, and students.
