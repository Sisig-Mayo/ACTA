# Running Acta

Run Acta with Flutter from the repository root.

## List Available Devices

```sh
flutter devices
```

## Run On The Default Device

```sh
flutter run
```

## Run On A Specific Target

Examples:

```sh
flutter run -d chrome
flutter run -d linux
flutter run -d macos
flutter run -d windows
```

Mobile targets require an emulator, simulator, or connected device.

## Current Expected Result

The current app displays a Material page with centered `Hello World!` text.

If you see that screen, the Flutter runtime, platform runner, and Dart entry
point are connected correctly.

## Build Commands

Common release build commands:

```sh
flutter build apk
flutter build ios
flutter build web
flutter build linux
flutter build macos
flutter build windows
```

Some build targets are only available on specific host operating systems.
