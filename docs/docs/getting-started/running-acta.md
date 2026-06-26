# Running ACTA

Run the backend and frontend as separate local processes.

## Start The Backend

From the repository root:

```sh
cd backend
source .venv/bin/activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Check the service:

```sh
curl http://localhost:8000/health
```

FastAPI interactive documentation is available at:

- `http://localhost:8000/docs`
- `http://localhost:8000/redoc`

## Start The Frontend

In another shell from the repository root:

```sh
flutter run -d chrome
```

Other supported Flutter targets depend on the host platform:

```sh
flutter run -d linux
flutter run -d macos
flutter run -d windows
```

Mobile targets require an emulator, simulator, or connected device.

## Local Backend URL

The current Flutter code calls `http://localhost:8000` directly in several
screens and providers. This works for Chrome and desktop local development.

For Android emulators, iOS simulators, physical devices, or deployed builds,
replace those hardcoded base URLs with target-appropriate configuration.

## Typical Operator Flow

1. Start the backend on port `8000`.
2. Start the Flutter app.
3. Register or log in through the ACTA login screen.
4. Configure and submit a simulation.
5. Poll status until the run is complete.
6. Review results, AI action plan, master action plan, and export/dispatch
   actions.

## Build Commands

Common Flutter build commands:

```sh
flutter build web
flutter build apk
flutter build ios
flutter build linux
flutter build macos
flutter build windows
```

Some build targets are only available on specific host operating systems.
