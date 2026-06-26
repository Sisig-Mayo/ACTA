# System Architecture

Acta currently uses Flutter's default single-entry application shape. There is
one Dart source file and no custom feature modules yet.

## Runtime Layers

The current runtime can be read as three layers:

1. **Platform runner** starts the Flutter engine for the selected platform.
2. **Flutter framework** loads the Dart application and widget tree.
3. **Acta root widget** renders the current UI.

## Entry Point

`lib/main.dart` contains the full application:

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}
```

`main()` delegates to Flutter through `runApp()`. The root widget is `MainApp`.

## Root Widget

`MainApp` extends `StatelessWidget`:

```dart
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}
```

The widget tree is:

- `MaterialApp`
- `Scaffold`
- `Center`
- `Text`

Because every widget in the tree is constant, the current UI has no mutable
state and no runtime configuration.

## Platform Projects

The platform folders are generated Flutter runner projects:

- `android/`
- `ios/`
- `linux/`
- `macos/`
- `web/`
- `windows/`

These folders contain the native shell code and build metadata required by
Flutter. Application behavior should normally be added under `lib/` unless a
platform-specific integration is required.

## Missing Application Systems

The following systems do not exist yet:

- Navigation and routing.
- Feature modules.
- State management.
- Data models.
- Networking.
- Persistence.
- Authentication.
- Theming beyond Flutter defaults.
- Localization.
- Custom platform channels.

Add these systems deliberately when product requirements need them. When a new
system is introduced, document its ownership, public API, and lifecycle in this
section or a linked page.
