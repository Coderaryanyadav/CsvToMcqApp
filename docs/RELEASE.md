# QuizPro — Release & Update-Safety Checklist

## 1. Versioning Protocol

QuizPro distinguishes between 4 independent version numbers:
1. **App Version**: Semantic version in `pubspec.yaml` (e.g. `2.0.0+3`).
2. **Storage Schema Version**: Tracked in `MigrationManager` and `meta.json` (e.g. `2`).
3. **Exam Content Schema Version**: Stored per question bank JSON (e.g. `2`).
4. **Backup Format Version**: Stored in exported backup JSONs (e.g. `1`).

---

## 2. Production Pre-Release Checklist

Before releasing any new version to production, verify:

### Pre-Release Verification
- [ ] Code formatted with `dart format .`
- [ ] Static analysis passes with zero warnings: `flutter analyze`
- [ ] Automated test suite passes: `flutter test`
- [ ] Migration upgrade simulation passes: `flutter test test/migration_upgrade_simulation_test.dart`
- [ ] Build artifacts generated successfully:
  - `flutter build apk --release` (Android)
  - `flutter build ipa --release` (iOS)
  - `flutter build macos --release` (macOS)

### In-Place Upgrade Verification
- [ ] Install previous production version.
- [ ] Create user profile, complete 10 exams, create bookmarks, and start an active session.
- [ ] Install new production version over the existing installation.
- [ ] Launch application and verify:
  - Active student profile remains selected.
  - All past exam history and scores remain identical.
  - All question banks and bookmarks are present.
  - Active session can be resumed.
  - New settings defaults are applied without corrupting existing preferences.

---

## 3. Production Release Process

1. Bump version in `pubspec.yaml` (`MAJOR.MINOR.PATCH+BUILD`).
2. Update `CHANGELOG.md` with release summary.
3. Commit and tag:
   ```bash
   git add pubspec.yaml CHANGELOG.md
   git commit -m "chore(release): prepare v2.0.0"
   git tag -a v2.0.0 -m "Release v2.0.0"
   git push origin main --tags
   ```
4. Publish release notes and binary assets to GitHub Releases / App Stores.
