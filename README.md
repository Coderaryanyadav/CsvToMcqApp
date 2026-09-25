# 🎓 QuizPro — Modern MCQ & Examination Simulator

[![Flutter CI](https://github.com/Coderaryanyadav/CsvToMcqApp/actions/workflows/flutter.yml/badge.svg)](https://github.com/Coderaryanyadav/CsvToMcqApp/actions/workflows/flutter.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)](README.md)
[![Live Web App](https://img.shields.io/badge/Live%20Web%20App-Vercel-black?style=for-the-badge&logo=vercel)](https://web-sandy-five-55.vercel.app)

**QuizPro** is a modern, cross-platform MCQ examination simulator and practice
application (available on the
**[Live Web App](https://web-sandy-five-55.vercel.app)**, Android, iOS, macOS,
Windows, and Linux). Designed for certification exams, standardized test
preparation, and custom question banks (e.g. AWS, CIA, CISA, SQL, and
personalized curriculums).

It combines a multi-student profile system, safe atomic local persistence,
resilient CSV/Excel import, timed and untimed exam simulation, interactive
practice mode with per-option explanations, and pure chronological analytics.

---

## 📸 Screenshots

| Dashboard & Overview                         | Question Import Preview                        | Exam Simulation Mode                    |
| -------------------------------------------- | ---------------------------------------------- | --------------------------------------- |
| ![Dashboard](docs/screenshots/dashboard.png) | ![Import Preview](docs/screenshots/import.png) | ![Exam Mode](docs/screenshots/exam.png) |

---

- **🛡️ Production Update-Safe Migration Engine**: Built-in `MigrationManager`
  guarantees that updating the application preserves 100% of user accounts,
  learning progress, practice history, exam records, bookmarks, and preferences
  without data resets.
- **🎯 Question-Type Selection & Filtering**: Explicitly choose which question
  types to practice or include in exam simulations (e.g. _Single Choice Only_,
  _Multiple Choice / Multiple Select Only_, _True/False_, or _All Types_).
  Real-time availability badges instantly reflect matching questions.
- **👥 Multi-Student Profiles & Data Isolation**: Create separate student
  profiles with custom avatar emojis and colors. Statistics, attempt histories,
  bookmarks, and sessions are isolated per active student.
- **📂 Flexible CSV & Excel (XLSX) Import**: Intelligent header alias
  normalization (`question_text`, `choice_1`–`4`, `correct_answer`,
  `explanation_a`–`d`, etc.) with duplicate detection and an interactive
  validation preview.
- **⏱️ Exam Simulator**: Timed and untimed exams, question navigation grid, flag
  for review, auto-submit on timer expiration, and lifecycle auto-saving
  (`WidgetsBindingObserver`).
- **📘 Interactive Practice Mode**: Instant answer validation, per-option
  explanations, and dedicated "Practice Mistakes" drilling.
- **⭐ Question Bookmarking & Revision Filter**: Star challenging questions
  across exams and practice; filter question banks to drill bookmarked items.
- **📈 Chronological Analytics & Snapshots**: Accurate learning curves
  calculated from oldest to newest attempts. Historical metadata snapshots
  ensure past test records remain reliable even if questions are edited or
  deleted later.
- **💾 Safe Atomic File Persistence**: Safe write staging (`.tmp_${timestamp}`
  -> flush -> rename/replace) ensures zero file corruption during power loss or
  abrupt OS suspension.
- **📦 Full Backup & Restore Packages**: Single-click JSON export/import of all
  student profiles, question banks, bookmarks, and past attempt history.
- **🌓 Real Dark Mode & Semantic Design System**: Supports `System`, `Light`,
  and `Dark` (slate palette) modes with instant reactive switching.
- **⌨️ Desktop Keyboard Shortcuts**: `1`-`4` or `A`-`D` for option selection,
  arrow keys for navigation, `Space`/`M` for review flags, and `Enter` to
  advance.

---

## 🌐 Supported Platforms

| Platform       | Support Tier | Notes                                                       |
| -------------- | ------------ | ----------------------------------------------------------- |
| 🤖 **Android** | Production   | Android 5.0+ (API 21+), ARM64 / ARMv7 / x86_64 release APKs |
| 🍏 **macOS**   | Production   | macOS 10.14+, Native Desktop UI with Keyboard Shortcuts     |
| 📱 **iOS**     | Production   | iOS 12.0+, Simulator & Physical Device                      |
| 🪟 **Windows** | Supported    | Windows 10+ Desktop                                         |
| 🐧 **Linux**   | Supported    | Linux Desktop (GTK)                                         |

---

## 📋 System Requirements

- **Flutter SDK**: `>=3.10.0` (Dart SDK `>=3.0.0 <4.0.0`)
- **Android Studio / Android SDK** (for Android builds)
- **Xcode & CocoaPods** (for iOS / macOS builds)

---

## 🛠️ Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/Coderaryanyadav/CsvToMcqApp.git
cd CsvToMcqApp
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run Locally

```bash
# Android
flutter run -d android

# macOS Desktop
flutter run -d macos

# iOS Simulator
flutter run -d ios
```

---

## 📥 Importing Questions

QuizPro supports both **CSV** and **Excel (.xlsx)** spreadsheet imports.

### CSV Format Specification

```csv
Question,Option A,Option B,Option C,Option D,Correct Answer,Explanation A,Explanation B,Explanation C,Explanation D,Topic,Difficulty,Tags
"What is Docker?",Container runtime,Operating system,Web browser,Database,A,"Docker manages containers","Not an OS","Not a browser","Not a database",DevOps,2,"containers,virtualization"
"Which are relational databases?",PostgreSQL,MongoDB,MySQL,Redis,A|C,"PostgreSQL is SQL","MongoDB is NoSQL","MySQL is SQL","Redis is Key-Value",Databases,3,"sql,rdbms"
```

### Supported Header Aliases

- **Question Prompt**: `question`, `question_text`, `prompt`, `q`
- **Options**: `option_a`–`option_d`, `choice_1`–`choice_4`
- **Correct Answer**: `correct_answer`, `correct`, `answer`, `key` (Supports
  `A`-`D`, `1`-`4`, multi-select `A|C`, or exact option text)
- **Explanations**: `explanation`, `explanation_a`–`explanation_d`
- **Metadata**: `topic`, `difficulty` (`1`–`5`), `tags`

---

## 💾 Local Storage & Privacy

- **100% Offline-First (User Data)**: All user data (student profiles, exams,
  question banks, progress) is stored locally on the user's device using JSON
  files in the application documents directory (`mcq_data/`).
- **Privacy Policy & Ad Integration**: The app includes an in-app Privacy Policy
  to comply with Google Play Store guidelines. While core functionality is
  completely offline, the app integrates the **Google Mobile Ads SDK (AdMob)**,
  which may collect device identifiers (like the Advertising ID), IP addresses,
  and crash logs for ad delivery and analytics purposes.
- **Atomic Persistence**: Disk writes utilize temporary staging files and atomic
  replacement to guard against corruption.
- **Portable Backups**: Users can export full backups or reset all application
  data anytime via **Settings → Data & Storage**.

---

## 🏛️ Project Architecture

```text
lib/
├── main.dart                   # Application entry point & theme listener
├── models/                     # Data models (Exam, Question, Performance, StudentProfile)
├── repositories/               # Storage repository abstraction & atomic IO implementation
├── services/                   # Business logic (MigrationManager, Analytics, Import, Backup, Streak)
├── screens/                    # UI screens (Home, Exam, Practice, QuestionBank, Statistics, Settings, Welcome)
├── theme/                      # Centralized design tokens (AppTheme, Light & Dark themes)
├── utils/                      # Input validators & helpers
└── widgets/                    # Reusable components (AppLogo, etc.)
```

### 📚 Architecture & Engineering Documentation

- [Data Architecture Blueprint](docs/DATA_ARCHITECTURE.md) — Comprehensive
  storage engine, persistence matrix, and lifecycle guarantees.
- [Schema & Migrations Guide](docs/MIGRATIONS.md) — Storage schema version
  registry, migration pipeline, and update contracts.
- [Release Checklist](docs/RELEASE.md) — Production release process and in-place
  upgrade verification steps.
- [Data Model Specification](docs/DATA_MODEL.md) — Complete JSON schemas and
  entity relationships.

---

## 🧪 Testing & Verification

Run the full automated test suite (including model serialization, student
isolation, atomic persistence, import engine, and widget tests):

```bash
# Code formatting check
dart format .

# Static analyzer
flutter analyze

# Automated tests
flutter test
```

---

### 🚀 One-Command Automated Build (All Platforms)

Run the master script to build all platforms and collect distribution artifacts
into `release_bundles/`:

```bash
./build_all.sh
```

### 🎯 Separated Platform Scripts

Individual platform scripts are available in `scripts/`:

- **Android APK & AAB**: `./scripts/build_android.sh` (`--aab` for Play Store
  bundle)
- **iOS / IPA**: `./scripts/build_ios.sh` (`--signed` for App Store certificate
  signing)
- **macOS Desktop**: `./scripts/build_macos.sh`
- **Windows Desktop**: `./scripts/build_windows.sh` (or
  `.\scripts\build_windows.ps1` / `.\scripts\build_windows.bat` on Windows)

---

### Manual Commands

#### 🤖 Android (Google Play Store & Sideload APK)

```bash
# 1. Google Play Store Release (AAB)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab

# 2. Universal Sideload APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### 🍏 macOS Desktop

```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/csv_to_mcq_app.app
```

#### 📱 iOS

```bash
flutter build ipa --release
# Output: build/ios/ipa/*.ipa
```

#### 🪟 Windows Desktop

```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

For detailed release checklists and deployment instructions, see
[docs/releasing.md](docs/releasing.md).

---

## 🌐 Live Web Application (Vercel)

The full-featured web application is deployed and hosted live on Vercel:

🚀 **Production Web App**: [https://web-sandy-five-55.vercel.app](https://web-sandy-five-55.vercel.app)

### Web App Highlights
- **Zero Preloaded Dummy Data**: Starts with a pure clean slate; optionally click `✨ Load Sample Test` for instant 1-click feature exploration.
- **Client-Side SHA-256 Authentication**: Secure account registration and login using browser native Web Crypto API with persistent encrypted vault storage, guest mode (`⚡ Continue as Guest`), and a `🎯 Try Demo Account` button.
- **☁️ Supabase Cloud Database Integration**: Connect your Supabase PostgreSQL database to sync exams, test banks, and attempt histories to the cloud.
- **🎉 Canvas Confetti Celebrations**: High-velocity multi-angle particle explosions triggered upon passing examinations and reaching study milestones.
- **🔊 Web Audio API Synthesizer**: Pure programmatic audio chimes for correct answers, buzzers for mistakes, and fanfare on test completion (toggleable with `🔊`).
- **Interactive Practice Arena & Timed Simulator**: Real-time option validation, bookmarking, elimination strikethroughs, and desktop keyboard navigation (`1-4`, `A-D`, `Arrow keys`, `Enter`, `M`, `B`).
- **Data Portability**: Full JSON backup export and restore compatible across web and desktop platforms.

---

## ☁️ Supabase Cloud Database Integration

QuizPro supports optional cloud persistence using **Supabase** (PostgreSQL):

### 1. Database Schema Setup
Run the SQL schema located in [`supabase/schema.sql`](supabase/schema.sql) in your Supabase project:
1. Go to your [Supabase Dashboard](https://supabase.com/dashboard) -> Select your Project.
2. Navigate to **SQL Editor** -> **New Query**.
3. Paste the contents of [`supabase/schema.sql`](supabase/schema.sql) and click **Run**.

### 2. Supported Tables
- `exams`: Examination catalog, durations, passing thresholds, and JSONB question banks.
- `students`: Profile metadata, target exam goals, avatars, and guest flags.
- `performances`: Chronological test attempts, scores, time spent, and answer audits.
- `bookmarks`: Question bookmarks per student.
- `streaks`: Daily study streak tracking.

### 3. Connecting to Supabase in the Web App
1. Open QuizPro Web -> Click **⚙️ Settings** in the top navigation.
2. Under **☁️ Supabase Cloud Database**, enter your:
   - **Project URL** (e.g. `https://your-project.supabase.co`)
   - **Anon Public Key** (`eyJhbGci...`)
3. Click **💾 Save Config** then **⚡ Test Connection**.
4. Use **⬆️ Push to Cloud** to upload your local exams, or **⬇️ Pull from Cloud** to download your cloud question banks to any device.

---

## 🚀 Deployment Instructions (Vercel)

To deploy the web app to your own Vercel account:

```bash
# 1. Install Vercel CLI (or use npx)
npm install -g vercel

# 2. Deploy from the web directory
cd web
vercel --prod
```

Or deploy directly from the repository root:
```bash
npx vercel web --prod --yes
```

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before submitting pull requests.

---

## 🔒 Security

For security vulnerability reporting, please see [SECURITY.md](SECURITY.md).

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file
for details.
