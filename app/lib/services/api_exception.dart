/// Raised by [ApiService] for any network/HTTP failure. `AppState` maps
/// this to a [PpConnectivity] state rather than crashing the UI —
/// see docs/API_CONTRACT.md "Error -> UI state mapping".
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
