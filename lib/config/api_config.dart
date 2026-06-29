/// Frontend API configuration.
///
/// Local development defaults to the FastAPI dev server. Production builds can
/// override this with:
///
///   flutter build web --dart-define=ACTA_API_BASE_URL=https://api.example.com
library;

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'ACTA_API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
