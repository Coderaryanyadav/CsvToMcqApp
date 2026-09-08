# Release Process & Guidelines

This document outlines the standard release lifecycle for **QuizPro**.

---

## 📌 Release Checklist

### 1. Pre-Release Verification

- [ ] Ensure all feature branches are merged into `main`.
- [ ] Run code formatter:
  ```bash
  dart format .
  ```
- [ ] Run static analyzer:
  ```bash
  flutter analyze
  ```
- [ ] Run automated test suite:
  ```bash
  flutter test
  ```
- [ ] Verify release builds locally:
  ```bash
  flutter build apk --release
  flutter build macos --release
  ```

---

### 2. Version Bump

- Update version in `pubspec.yaml` following Semantic Versioning
  (`MAJOR.MINOR.PATCH+BUILD`):
  ```yaml
  version: 1.1.0+2
  ```
- Update `CHANGELOG.md` with new features, fixes, and improvements under the new
  release header.

---

### 3. Git Tagging & Commit

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore(release): prepare v1.1.0"
git tag -a v1.1.0 -m "Release v1.1.0"
```

---

### 4. GitHub Release

1. Push release commit and tags to the remote repository:
   ```bash
   git push origin main
   git push origin v1.1.0
   ```
2. Navigate to **Releases** on GitHub.
3. Click **Draft a new release**, select tag `v1.1.0`.
4. Copy the release notes from `CHANGELOG.md`.
5. Attach compiled release artifacts (`app-release.apk`, macOS `.zip`, etc.).
6. Click **Publish release**.
