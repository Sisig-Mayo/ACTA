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

The Flutter frontend reads its backend URL from `lib/config/api_config.dart`.
The default is the deployed ACTA backend:

```text
https://acta-production.up.railway.app
```

Override it at build or run time with `ACTA_API_BASE_URL`:

```sh
flutter run -d chrome --dart-define=ACTA_API_BASE_URL=http://localhost:8000
flutter build web --dart-define=ACTA_API_BASE_URL=https://api.example.com
```

Use a URL that is reachable from the target device. Chrome and desktop apps can
use `http://localhost:8000` when the backend is running on the same machine.
Android emulators, iOS simulators, physical devices, and deployed web builds
usually need a different host.

## Typical Operator Flow

1. Start the backend on port `8000`.
2. Start the Flutter app.
3. Register or log in through the ACTA login screen.
4. Configure and submit a simulation.
5. Poll status until the run is complete.
6. Review results, AI action plan, master action plan, and export/dispatch
   actions.

For prototype demonstrations, Simulation Setup also includes **Use Demo
Result**. This loads a local representative flood scenario and jumps directly to
the AI Action Plan. It is intended as a presentation fallback when the network
or backend is unavailable; it does not call the simulation API.

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
