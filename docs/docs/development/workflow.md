# Development Workflow

This page records the expected workflow for changing Acta.

## Before Making Changes

Install dependencies:

```sh
flutter pub get
```

Check that Flutter sees your target platform:

```sh
flutter doctor
flutter devices
```

## Code Style

Acta uses the Flutter recommended lint package:

```yaml
dev_dependencies:
  flutter_lints: ^6.0.0
```

Analyze the project with:

```sh
flutter analyze
```

Keep Dart code formatted with:

```sh
dart format .
```

## Testing

The project includes the `flutter_test` dependency, but no test files are
currently present.

When behavior is added, prefer focused widget tests for UI behavior and unit
tests for pure Dart logic.

Run tests with:

```sh
flutter test
```

## Documentation Changes

Documentation lives in `docs/docs/`. Update it when a change affects:

- Startup flow.
- Project structure.
- Build or run commands.
- Architecture.
- Public conventions contributors should follow.

Preview the site locally with:

```sh
mkdocs serve -f docs/mkdocs.yml
```

Build the static documentation with:

```sh
mkdocs build -f docs/mkdocs.yml
```
