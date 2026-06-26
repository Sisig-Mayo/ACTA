# Acta

Acta is a Flutter application scaffolded for multi-platform delivery. The
current codebase is intentionally small: the Dart application entry point starts
a `MaterialApp`, renders a single `Scaffold`, and displays `Hello World!` in the
center of the screen.

This documentation records the system as it exists today and gives contributors
a stable place to add design notes as Acta grows.

!!! note "Current application scope"
    Acta does not yet define product-specific screens, business logic, custom
    routing, persistence, networking, generated assets, or platform plugins. The
    project is currently a clean Flutter foundation.

## What Is In The System

The repository contains:

- A Flutter application package named `acta`.
- A single Dart entry point at `lib/main.dart`.
- Generated platform runner projects for Android, iOS, Linux, macOS, Windows,
  and web.
- Flutter lint configuration through `flutter_lints`.
- A MkDocs documentation project using the ReadTheDocs theme.

## Primary Runtime Flow

Acta starts from `main()`:

```dart
void main() {
  runApp(const MainApp());
}
```

`MainApp` is a stateless root widget. It returns a `MaterialApp` whose `home` is
a `Scaffold` with centered text.

This means there is currently no app-wide dependency container, state management
layer, router, theme object, localization setup, or feature module boundary.

## Documentation Layout

Use the left navigation to move through the manual:

- **Getting Started** explains how to install dependencies and run Acta.
- **Development** describes the current architecture and contribution workflow.
- **Reference** documents the repository layout and configuration files.

As the application gains real screens and systems, add new pages beside the
existing sections instead of overloading this overview.
