/// Frontend API configuration.
///
/// Builds can override this with:
///
///   flutter build web --dart-define=ACTA_API_BASE_URL=https://api.example.com
library;

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'ACTA_API_BASE_URL',
    defaultValue: 'https://acta-production.up.railway.app',
  );
}
