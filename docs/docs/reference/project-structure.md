# Project Structure

The repository follows Flutter's standard multi-platform layout.

```text
ACTA/
├── android/
├── ios/
├── lib/
│   └── main.dart
├── linux/
├── macos/
├── web/
├── windows/
├── docs/
│   ├── mkdocs.yml
│   └── docs/
├── analysis_options.yaml
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

## Application Code

`lib/main.dart`

: Contains the application entry point and root widget. This is currently the
  only Dart application source file.

## Package Configuration

`pubspec.yaml`

: Defines package metadata, SDK constraints, runtime dependencies, development
  dependencies, and Flutter asset settings.

`pubspec.lock`

: Records resolved package versions. Keep this file committed for reproducible
  app builds.

`analysis_options.yaml`

: Configures Dart analyzer and lint rules.

## Platform Runners

The platform folders contain generated runner projects used by Flutter to build
native shells:

- `android/`
- `ios/`
- `linux/`
- `macos/`
- `web/`
- `windows/`

Most product code should live in `lib/`. Edit platform folders only when
integrating platform-specific capabilities or changing app metadata.

## Documentation

`docs/mkdocs.yml`

: Configures the documentation site, navigation, Markdown extensions, and
  ReadTheDocs theme.

`docs/docs/`

: Contains the Markdown source pages for the documentation site.
