# 🎓 QuizPro — Comprehensive Platform Architecture & User Guide

Welcome to the technical documentation and user guide for **QuizPro**. This document details the architectural layout, data model schemas, local database persistence layer, responsive UX design, and validation engines.

---

## 📑 Table of Contents

1. [Architectural Overview](#1-architectural-overview)
2. [Data Layer & Database Persistence](#2-data-layer--database-persistence)
3. [Multi-Student Profile Architecture](#3-multi-student-profile-architecture)
4. [Exam & Practice Engine](#4-exam--practice-engine)
5. [CSV & Excel Import Specifications](#5-csv--excel-import-specifications)
6. [Design System & Theme Tokens](#6-design-system--theme-tokens)
7. [Quality Assurance & Test Matrix](#7-quality-assurance--test-matrix)

---

## 1. Architectural Overview

QuizPro follows a clean, repository-based architecture isolating the UI layer, state management, validation services, and persistent I/O:

```
lib/
├── main.dart                  # Application entry point & student routing
├── models/                    # Immutable data transfer objects (DTOs)
│   ├── exam.dart              # Exam track and question collection
│   ├── performance.dart       # Graded test attempt with topic breakdown
│   ├── question.dart          # Single/Multi-select MCQ with explanations
│   └── student_profile.dart   # Student profile with avatar emoji and color
├── repositories/              # Persistent database layer
│   └── storage_repository.dart# In-memory cached file repository with atomic flush
├── screens/                   # User interface pages & modals
│   ├── add_edit_exam_screen.dart
│   ├── exam_audit_screen.dart
│   ├── exam_screen.dart       # Responsive timed/untimed exam simulation
│   ├── home_screen.dart       # Dashboard, active student switcher & tabs
│   ├── import_preview_screen.dart
│   ├── practice_mode_screen.dart
│   ├── question_bank_screen.dart
│   ├── result_screen.dart
│   ├── settings_screen.dart
│   ├── statistics_screen.dart
│   ├── take_exam_screen.dart
│   └── welcome_screen.dart    # Multi-student onboarding & switcher
├── services/                  # Business logic services
│   ├── analytics_service.dart
│   ├── exam_audit_service.dart
│   ├── import_service.dart
│   └── storage_service.dart
├── theme/
│   └── app_theme.dart         # Material 3 color palettes and styling
├── utils/
│   └── validators.dart        # Schema and input validators
└── widgets/
    └── app_logo.dart
```

---

## 2. Data Layer & Database Persistence

### Persistent Storage Location
Data is permanently stored on the host device under `<app_documents>/mcq_data/`:
- `students.json`: Serialized array of all `StudentProfile` records.
- `settings.json`: Key-value map including `activeStudentId`, `themeMode`, `fontSize`, `hapticFeedback`, `defaultDuration`, and `defaultPassingScore`.
- `<exam_id>.json`: Dedicated file per exam track containing metadata, passing percentage, and question bank.
- `performance_<exam_id>_<timestamp>_<student_id>.json`: Timestamped, microsecond-unique graded attempt records.
- `session_<exam_id>.json`: Autosaved session states for interrupted exams.

### High Performance In-Memory Caching
- Lookups (`getAllExams()`, `getAllStudents()`, `getSettings()`) query in-memory caches ($O(1)$) to prevent frame drops during scrolling or navigation.
- Mutations (`saveExam()`, `saveStudent()`, `deleteExam()`) invalidate/update the cache and immediately execute atomic disk writes using `flush: true`.

---

## 3. Multi-Student Profile Architecture

Each student profile encapsulates:
- `id`: Unique UUID.
- `name`: Display name.
- `avatarEmoji`: Visual avatar glyph (e.g. 🎓, 👩‍💻, 👨‍🎓, 🚀).
- `avatarColorValue`: Primary accent color hex integer.
- `createdAt`: ISO-8601 timestamp.

### Profile Switching & Data Isolation
- Switching profiles updates `settings.json['activeStudentId']`.
- History and dashboard statistics automatically filter records by `p.studentId == activeStudent.id`.

---

## 4. Exam & Practice Engine

### Exam Mode
- **Responsive Layout**: On wide desktop screens (>750px), displays a split-view with a question index sidebar. On mobile screens (<750px), the sidebar transitions into a modal bottom sheet navigator.
- **Timer Engine**: `Timer.periodic` triggers every 1,000ms. When remaining time hits `0:00`, it immediately halts, grades all answers, saves the performance record, and navigates to `ResultScreen`.
- **Question Availability Checks**: Validates that the requested question count does not exceed available questions in the question bank.

### Practice Mode
- Provides instant answer feedback upon option selection.
- Displays comprehensive per-option explanations.
- Tracks time elapsed and records results to student performance logs upon completion.

---

## 5. CSV & Excel Import Specifications

| Column | Accepted Aliases | Description |
|---|---|---|
| **Question** | `question`, `question_text`, `prompt`, `q` | The main question stem text |
| **Option A** | `option_a`, `choice_a`, `a`, `opt_a`, `option 1` | Choice A text |
| **Option B** | `option_b`, `choice_b`, `b`, `opt_b`, `option 2` | Choice B text |
| **Option C** | `option_c`, `choice_c`, `c`, `opt_c`, `option 3` | Choice C text |
| **Option D** | `option_d`, `choice_d`, `d`, `opt_d`, `option 4` | Choice D text |
| **Correct Answer** | `correct_answer`, `answer`, `key`, `correct` | Key: `A`, `1`, `A\|C`, `1\|3`, or exact text |
| **Explanation A..D** | `explanation_a`..`explanation_d` | Optional per-option explanations |
| **Topic** | `topic`, `category`, `domain` | Subject area categorization |
| **Difficulty** | `difficulty`, `level`, `diff` | Integer rating from 1 (Easy) to 5 (Hard) |
| **Tags** | `tags`, `keywords`, `labels` | Comma-separated search tags |

---

## 6. Design System & Theme Tokens

Defined in [`lib/theme/app_theme.dart`](lib/theme/app_theme.dart):
- **Background**: `#F8F9FB` (Light) / `#0F172A` (Dark)
- **Surface**: `#FFFFFF` (Light) / `#1E293B` (Dark)
- **Primary Navy**: `#1E3A5F`
- **Accent Blue**: `#2563EB`
- **Success**: `#16A34A`
- **Danger**: `#DC2626`
- **Warning**: `#D97706`

---

## 7. Quality Assurance & Test Matrix

Run all tests via:
```bash
flutter test
```

- **46 Automated Tests Passing**:
  - `database_persistence_test.dart`: Multi-session cold restart simulations & atomic writes.
  - `student_profile_test.dart`: Profile creation and persistence.
  - `analytics_test.dart`: Chronological score calculations and metric accuracy.
  - `import_test.dart`: Header alias normalization and error catching.
  - `exam_session_test.dart`: DTO JSON serialization and deserialization.
  - `validators_test.dart`: Boundary validation rules.
  - `widget_test.dart`: Interactive widget UI flow tests.
