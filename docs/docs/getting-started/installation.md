# Installation

Acta is a Flutter project. A working Flutter SDK is required before the app can
be built or run.

## Requirements

- Flutter SDK compatible with Dart `^3.12.2`.
- A platform toolchain for the target you want to run:
  - Android Studio or Android command-line tools for Android.
  - Xcode for iOS and macOS.
  - A modern browser for web.
  - Linux desktop dependencies for Linux.
  - Visual Studio with desktop C++ tooling for Windows.

Check your local environment with:

```sh
flutter doctor
```

Resolve any missing platform requirements reported by Flutter before running the
application.

## Fetch Dependencies

From the repository root:

```sh
flutter pub get
```

The project currently depends only on the Flutter SDK at runtime. Development
uses `flutter_test` and `flutter_lints`.

## Documentation Tools

The documentation site is built with MkDocs:

```sh
mkdocs serve
```

The MkDocs configuration lives at `docs/mkdocs.yml`, and the documentation pages
live under `docs/docs/`.
