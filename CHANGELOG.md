# Changelog

All notable changes to the **QuizPro** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-09-08

### Added
- **Multi-Student Profiles**: Seamless student switching with custom avatar emojis, colors, and isolated statistics.
- **CSV/Excel/JSON Importer**: Normalized header mapping, strict validation, duplicate detection, and import preview modal.
- **Exam Simulator**: Timed and untimed modes, auto-submit countdowns, question navigator, and bookmark flags.
- **Interactive Practice Mode**: Instant explanation reveal, option breakdown, and targeted "Practice Mistakes" drilling.
- **Question Bookmarking**: Star challenging questions across exams and practice for targeted revision.
- **Habit Tracking**: Daily study goals and consecutive study day streaks 🔥.
- **Full Data Backup & Restore**: Single-click export and import of all student profiles, question banks, and history as portable JSON packages.
- **Desktop Shortcuts**: Keyboard controls (`1-4`, `A-D`, `Arrows`, `Space`, `M`, `Enter`) on macOS/Windows/Linux.
- **Theme Modes**: Full support for `System`, `Light`, and `Dark` (slate palette) theme modes with reactive switching.

### Changed
- **Storage Architecture**: Converted storage writes to true safe atomic persistence (staging write -> flush -> rename/replace).
- **Asynchronous I/O**: Removed synchronous file operations from UI paths to prevent thread stuttering on large question banks.
- **Analytics**: Refactored analytics engine into pure functions with strict chronological improvement calculations and historical question snapshots.

### Fixed
- Fixed dark mode toggle in `main.dart` and `settings_screen.dart`.
- Fixed student isolation across dashboard, statistics, and history queries.
- Fixed session restore boundary validation and malformed state recovery.
- Fixed untimed exam `copyWith()` duration transitions.
