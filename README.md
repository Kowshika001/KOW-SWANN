# love_app 🚀

A Flutter application contained in the `love_app` subfolder. This repository
includes a GitHub Actions pipeline that runs the widget tests on every push
and automatically builds a release APK. When a GitHub **release** is created
the workflow will attach the generated `.apk` file to the release assets.

---

## Quick start

1. **Clone the repo** and open in VS Code:
   ```bash
   git clone ...
   cd kowshikaandswann
   code .
   ```
2. Navigate into the Flutter project:
   ```bash
   cd love_app
   flutter pub get
   flutter run
   ```

---

## Testing & CI ✅

Any commit pushed to `main`/`master` triggers the `CI – test & build` workflow:

- runs `flutter test` (the existing widget test in `test/widget_test.dart`).
- builds a release APK and uploads it as a workflow artifact.

You can also run the workflow manually via the **Actions** tab.

---

## Releases & APK distribution 📦

Create a new [GitHub release](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
and the same workflow will build the APK and automatically attach it as an
asset called `app-release-apk` to the release. No manual steps are required.

> **Note:** the APK is generated from the commit tagged in the release.

---

## Resources

- [Flutter documentation](https://docs.flutter.dev/)
- [Writing your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [GitHub Actions: uploading release assets](https://docs.github.com/actions/guides/publishing-build-artifacts#uploading-build-artifacts-to-github-releases)

