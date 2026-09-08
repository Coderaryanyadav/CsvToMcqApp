# Contributing to QuizPro

Thank you for your interest in contributing to QuizPro! We welcome community contributions, bug reports, and feature proposals.

---

## 🛠️ Development Setup

### 1. Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (stable channel)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / Xcode / VS Code with Flutter extension

### 2. Fork & Clone
```bash
git clone https://github.com/<your-username>/csv-to-mcq-app.git
cd csv-to-mcq-app
flutter pub get
```

---

## 🧪 Quality Standards & Workflow

Before submitting a pull request, ensure all local checks pass:

### 1. Code Formatting
```bash
dart format .
```

### 2. Static Analysis
```bash
flutter analyze
```
All code must pass with **0 errors, 0 warnings, and 0 lints**.

### 3. Automated Tests
```bash
flutter test
```
All unit, widget, and storage persistence tests must pass.

---

## 🌿 Branching Strategy & Pull Requests

1. **Create a topic branch**:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```
2. **Commit with clear conventional messages**:
   - `feat: add new exam filter option`
   - `fix: resolve session restore boundary validation`
   - `test: add coverage for student profile isolation`
   - `docs: update CSV header format documentation`
3. **Open a Pull Request**:
   - Fill out the PR template completely.
   - Link related issues.
   - Verify CI passes.

---

## 📄 Code of Conduct
All contributors are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).
