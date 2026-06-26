# Development Workflow

This page records the expected workflow for changing ACTA.

## Before Making Changes

Install frontend dependencies:

```sh
flutter pub get
```

Install backend dependencies:

```sh
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Confirm Flutter can see the target platform:

```sh
flutter doctor
flutter devices
```

## Code Style

Analyze Flutter code with:

```sh
flutter analyze
```

Format Dart code with:

```sh
dart format .
```

Keep Python changes formatted consistently with the surrounding backend code.
The repository does not currently define a Python formatter command.

## Testing

Run Flutter tests:

```sh
flutter test
```

Run backend tests from the `backend/` directory:

```sh
pytest
```

If `pytest` is not available in the active environment, install the test tool in
the backend virtual environment before running the suite.

## Database Changes

Put schema changes in `database/migrations/`. Use monotonically increasing
filenames and avoid duplicate migration numbers.

When a migration changes API behavior or required seed data, update:

- `docs/docs/reference/data-and-database.md`
- `docs/docs/reference/api.md`
- `.env.example` if new environment values are needed.

## Documentation Changes

Documentation source lives in `docs/docs/`. Update docs when a change affects:

- Startup flow.
- Environment variables.
- Project structure.
- API contracts.
- Database or spatial data contracts.
- Simulation or LLM behavior.
- Public conventions contributors should follow.

Preview locally:

```sh
mkdocs serve -f docs/mkdocs.yml
```

Build static docs:

```sh
mkdocs build -f docs/mkdocs.yml
```

`docs/site/` is generated MkDocs output. Rebuild it from source when publishing
the documentation site.
