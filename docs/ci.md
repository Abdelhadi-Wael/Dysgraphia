# Checks and builds

## Before each commit (on your computer)

`.githooks/pre-commit` checks formatting (`dart format`) and runs
`flutter analyze`. It takes a few seconds and stops the commit if either fails.
Tests are left to CI so committing stays quick.

Turn it on once per clone:

```bash
git config core.hooksPath .githooks
```

To fix formatting: `dart format lib test`.

## On every pull request (CI)

`.github/workflows/ci.yml` runs on GitHub for every pull request and every push
to `master`:

1. formatting check
2. `flutter analyze`
3. `flutter test`

The result shows on the pull request. To make passing checks required before
merging: GitHub → Settings → Branches → add a rule for `master` → "Require status
checks to pass" → choose **Format, analyze and test**.

## APK builds (CD)

`.github/workflows/build.yml` builds release APKs, one per phone type
(`--split-per-abi`), which keeps each file small. Most current phones need the
`arm64-v8a` one.

- **After a merge to `master`:** the APKs are attached to the workflow run
  (Actions tab → the run → Artifacts) for 30 days.
- **On a version tag:** a GitHub Release is also created with the APKs:

  ```bash
  git tag v0.3.0
  git push origin v0.3.0
  ```

- It can also be started by hand from the Actions tab ("Run workflow").

The APKs are signed with Flutter's debug key: fine for installing and testing,
not for the Play Store. A real signing key would be added as a GitHub secret.

Both workflows use Flutter 3.50.0. Update `flutter-version` in both files when
the project moves to a newer Flutter.
