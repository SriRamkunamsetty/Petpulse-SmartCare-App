import 'dart:async';

import 'api_service.dart';
import '../models/telemetry.dart';

/// Polls `GET /api/v1/telemetry` on the cadence documented in
/// docs/API_CONTRACT.md: 5s in "fast" mode (Home/Camera foregrounded),
/// 30s otherwise, with exponential backoff on failure.
class PollingService {
  PollingService(this._api);

  final ApiService _api;
  Timer? _timer;
  int _consecutiveFailures = 0;
  bool _fast = true;
  bool _disposed = false;

  final _controller = StreamController<Telemetry>.broadcast();
  Stream<Telemetry> get stream => _controller.stream;

  void start() {
    _scheduleNext(Duration.zero);
  }

  void setFastMode(bool fast) {
    _fast = fast;
  }

  void _scheduleNext(Duration delay) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, _tick);
  }

  Future<void> _tick() async {
    if (_disposed) return;
    try {
      final telemetry = await _api.getTelemetry();
      _consecutiveFailures = 0;
      if (!_controller.isClosed) _controller.add(telemetry);
      _scheduleNext(
          _fast ? const Duration(seconds: 5) : const Duration(seconds: 30));
    } catch (e) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 2 && !_controller.isClosed) {
        _controller.add(Telemetry.placeholder());
      }
      final backoffSeconds =
          [1, 2, 4, 8, 16, 30][(_consecutiveFailures - 1).clamp(0, 5)];
      _scheduleNext(Duration(seconds: backoffSeconds));
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.close();
  }
}
