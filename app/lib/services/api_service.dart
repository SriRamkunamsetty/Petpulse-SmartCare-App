import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_item.dart';
import '../models/device.dart';
import '../models/feeding_event.dart';
import '../models/pet.dart';
import '../models/schedule_entry.dart';
import '../models/telemetry.dart';
import 'api_exception.dart';

/// REST client for the contract in docs/API_CONTRACT.md.
///
/// Two *separate* local devices can be configured, each only used for the
/// endpoints it actually implements — see docs/API_CONTRACT.md and
/// firmware/README.md for why this isn't one blanket "prefer local" rule:
///
/// - The **hub** (`esp32s3_hub.ino`) only serves `/health`,
///   `/api/v1/telemetry`, and `/api/v1/feed/manual*`. Every other call
///   (pet, devices, schedule, history, alerts) always goes to the cloud/
///   mock base — routing those through the hub used to 404 and silently
///   roll back optimistic UI updates (schedule toggle, add-schedule).
/// - The **camera** (`esp32_cam.ino`) is a different physical board with
///   its own IP — camera endpoints go straight to it, never through the
///   hub or cloud base at all.
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const defaultCloudBaseUrl = 'https://api.petpulse.example';
  static const _localTimeout = Duration(milliseconds: 800);
  static const _requestTimeout = Duration(seconds: 10);
  // A free-tier host (e.g. Render's free web service plan) spins down after
  // idling and can take 30-60s to wake back up on the next request. Rather
  // than let that surface as a hard "Couldn't reach PetPulse" failure, cloud
  // calls get a short first attempt, then — only if that times out — one
  // slower retry long enough to ride out a cold start.
  static const _cloudFirstTimeout = Duration(seconds: 6);
  static const _cloudWakeTimeout = Duration(seconds: 55);

  /// True while a cloud request is being retried after an initial timeout —
  /// most likely the free-tier backend waking from an idle sleep. UI (see
  /// main.dart's bootstrap gate) can listen to this to show a "waking up"
  /// message instead of an error during that window.
  final ValueNotifier<bool> isWakingCloud = ValueNotifier(false);

  String? _token;
  String? _localBaseUrl;
  String? _camBaseUrl;
  String _cloudBaseUrl = defaultCloudBaseUrl;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('pp_auth_token');
    _localBaseUrl = prefs.getString('pp_local_base_url');
    _camBaseUrl = prefs.getString('pp_cam_base_url');
    _cloudBaseUrl = prefs.getString('pp_cloud_base_url') ?? defaultCloudBaseUrl;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pp_auth_token', token);
  }

  Future<void> setLocalHubIp(String ip) async {
    _localBaseUrl = 'http://$ip';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pp_local_base_url', _localBaseUrl!);
  }

  Future<void> setLocalCamIp(String ip) async {
    _camBaseUrl = 'http://$ip';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pp_cam_base_url', _camBaseUrl!);
  }

  Future<void> setCloudBaseUrl(String url) async {
    _cloudBaseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pp_cloud_base_url', url);
  }

  String get cloudBaseUrl => _cloudBaseUrl;
  String? get localBaseUrl => _localBaseUrl;
  String? get camBaseUrl => _camBaseUrl;
  bool get hasToken => _token != null;

  /// Immediate pass/fail check against a hub IP — used by the "Feeder Hub"
  /// card in Settings so entering an IP gives instant feedback, instead of
  /// waiting for the next background telemetry poll to find out.
  Future<bool> testLocalHub(String ip) => _healthCheck(ip);

  /// Same idea for the camera's own IP.
  Future<bool> testLocalCam(String ip) => _healthCheck(ip);

  /// Same idea for the cloud/mock server's full URL (e.g. a Render
  /// deployment) — used by the "PetPulse Server" card in Settings. Tolerates
  /// a free-tier cold start the same way normal cloud calls do, so a sleepy
  /// server doesn't read as "unreachable" on the first tap.
  Future<bool> testCloudUrl(String url) async {
    try {
      final res = await _client
          .get(Uri.parse('$url/health'))
          .timeout(_cloudFirstTimeout);
      return res.statusCode == 200;
    } on TimeoutException {
      isWakingCloud.value = true;
      try {
        final res = await _client
            .get(Uri.parse('$url/health'))
            .timeout(_cloudWakeTimeout);
        return res.statusCode == 200;
      } catch (_) {
        return false;
      } finally {
        isWakingCloud.value = false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> _healthCheck(String ip) async {
    try {
      final res = await _client
          .get(Uri.parse('http://$ip/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// [preferLocal] must only be true for endpoints the hub firmware
  /// actually implements (telemetry, feed) — see the class doc comment.
  Future<String> _resolveBaseUrl({required bool preferLocal}) async {
    if (!preferLocal) return _cloudBaseUrl;
    final local = _localBaseUrl;
    if (local != null) {
      try {
        final res = await _client
            .get(Uri.parse('$local/health'))
            .timeout(_localTimeout);
        if (res.statusCode == 200) return local;
      } catch (_) {
        // Local hub unreachable (different network, hub off) — fall through.
      }
    }
    return _cloudBaseUrl;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Runs [send] with a normal timeout for local-hub/cam calls. For cloud
  /// calls, tries a short timeout first and — only on a timeout — retries
  /// once with a much longer one, flipping [isWakingCloud] on for the
  /// duration so UI can show a "waking up" state instead of an error while
  /// a free-tier host cold-starts.
  Future<http.Response> _sendCloudAware(String base,
      Future<http.Response> Function(Duration timeout) send) async {
    if (base != _cloudBaseUrl) {
      return send(_requestTimeout);
    }
    try {
      return await send(_cloudFirstTimeout);
    } on TimeoutException {
      isWakingCloud.value = true;
      try {
        return await send(_cloudWakeTimeout);
      } finally {
        isWakingCloud.value = false;
      }
    }
  }

  Future<dynamic> _get(String path, {bool preferLocal = false}) async {
    final base = await _resolveBaseUrl(preferLocal: preferLocal);
    try {
      final res = await _sendCloudAware(
          base,
          (timeout) => _client
              .get(Uri.parse('$base$path'), headers: _headers)
              .timeout(timeout));
      return _decode(res);
    } on TimeoutException {
      throw const ApiException('Request timed out');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> _post(String path,
      [Map<String, dynamic>? body, bool preferLocal = false]) async {
    final base = await _resolveBaseUrl(preferLocal: preferLocal);
    try {
      final res = await _sendCloudAware(
          base,
          (timeout) => _client
              .post(Uri.parse('$base$path'),
                  headers: _headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(timeout));
      return _decode(res);
    } on TimeoutException {
      throw const ApiException('Request timed out');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final base = await _resolveBaseUrl(preferLocal: false);
    try {
      final res = await _sendCloudAware(
          base,
          (timeout) => _client
              .patch(Uri.parse('$base$path'),
                  headers: _headers, body: jsonEncode(body))
              .timeout(timeout));
      return _decode(res);
    } on TimeoutException {
      throw const ApiException('Request timed out');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final base = await _resolveBaseUrl(preferLocal: false);
    try {
      final res = await _sendCloudAware(
          base,
          (timeout) => _client
              .put(Uri.parse('$base$path'),
                  headers: _headers, body: jsonEncode(body))
              .timeout(timeout));
      return _decode(res);
    } on TimeoutException {
      throw const ApiException('Request timed out');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<void> _delete(String path) async {
    final base = await _resolveBaseUrl(preferLocal: false);
    try {
      final res = await _sendCloudAware(
          base,
          (timeout) => _client
              .delete(Uri.parse('$base$path'), headers: _headers)
              .timeout(timeout));
      if (res.statusCode >= 400) {
        throw ApiException('HTTP ${res.statusCode}',
            statusCode: res.statusCode);
      }
    } on TimeoutException {
      throw const ApiException('Request timed out');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 400) {
      throw ApiException('HTTP ${res.statusCode}: ${res.body}',
          statusCode: res.statusCode);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  // ── Auth ────────────────────────────────────────────────────────────
  Future<String> login(String email, String password) async {
    final json = await _post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
    final token = json['token'] as String;
    await setToken(token);
    return token;
  }

  Future<String> register(String email, String password) async {
    final json = await _post('/api/v1/auth/register', {
      'email': email,
      'password': password,
    });
    final token = json['token'] as String;
    await setToken(token);
    return token;
  }

  // ── Pet ─────────────────────────────────────────────────────────────
  Future<Pet> getPet() async => Pet.fromJson(await _get('/api/v1/pet'));

  Future<Pet> savePet(Pet pet) async =>
      Pet.fromJson(await _put('/api/v1/pet', pet.toJson()));

  // ── Devices / pairing ──────────────────────────────────────────────
  Future<List<Device>> getDevices() async {
    final list = await _get('/api/v1/devices') as List;
    return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> startPairing() async {
    final json = await _post('/api/v1/devices/pair/start');
    return json['session_id'] as String;
  }

  Future<PairingStatus> getPairingStatus(String sessionId) async {
    final json =
        await _get('/api/v1/devices/pair/status?session_id=$sessionId');
    return PairingStatus(
      state: json['state'] as String,
      device: json['device'] != null
          ? Device.fromJson(json['device'] as Map<String, dynamic>)
          : null,
    );
  }

  Future<Device> confirmPairing(String sessionId) async {
    final json =
        await _post('/api/v1/devices/pair/confirm', {'session_id': sessionId});
    final device = Device.fromJson(json as Map<String, dynamic>);
    if (device.kind == DeviceKind.hub && device.ipAddress != null) {
      await setLocalHubIp(device.ipAddress!);
    }
    return device;
  }

  // ── Telemetry (hub-only — real sensor data) ────────────────────────
  Future<Telemetry> getTelemetry() async =>
      Telemetry.fromJson(await _get('/api/v1/telemetry', preferLocal: true));

  // ── Manual feed (hub-only — drives the SG90 directly) ──────────────
  Future<String> startManualFeed(int grams) async {
    final json = await _post('/api/v1/feed/manual', {'grams': grams}, true);
    return json['job_id'] as String;
  }

  Future<FeedJobStatus> getFeedJobStatus(String jobId) async {
    final json = await _get('/api/v1/feed/manual/$jobId', preferLocal: true);
    return FeedJobStatus(
      status: json['status'] as String,
      dispensedGrams: (json['dispensed_grams'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Schedule (always cloud/mock — the hub doesn't store this) ──────
  Future<List<ScheduleEntry>> getSchedule() async {
    final list = await _get('/api/v1/schedule') as List;
    return list
        .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ScheduleEntry> addScheduleEntry(
      String day, String time, int grams) async {
    final json = await _post(
        '/api/v1/schedule', {'day': day, 'time': time, 'grams': grams});
    return ScheduleEntry.fromJson(json as Map<String, dynamic>);
  }

  Future<void> setScheduleEnabled(String id, bool enabled) async {
    await _patch('/api/v1/schedule/$id', {'enabled': enabled});
  }

  Future<void> deleteScheduleEntry(String id) async {
    await _delete('/api/v1/schedule/$id');
  }

  // ── History ─────────────────────────────────────────────────────────
  Future<HistoryResponse> getHistory({String range = 'week'}) async {
    final json = await _get('/api/v1/history?range=$range');
    return HistoryResponse(
      bars: (json['bars'] as List)
          .map((e) => DayIntake.fromJson(e as Map<String, dynamic>))
          .toList(),
      events: (json['events'] as List)
          .map((e) => FeedingEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Alerts ──────────────────────────────────────────────────────────
  Future<List<AlertItem>> getAlerts() async {
    final list = await _get('/api/v1/alerts') as List;
    return list
        .map((e) => AlertItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAlertRead(String id) async {
    await _post('/api/v1/alerts/$id/read');
  }

  // ── Camera (always the cam's own IP — a separate board from the hub) ─
  // Synchronous by design (no network call actually happens to resolve a
  // URL) — this also means CameraScreen picks up a newly-saved cam IP the
  // moment it next rebuilds, instead of a Future cached from initState().
  bool get hasCam => _camBaseUrl != null;

  String? get cameraStreamUrl =>
      _camBaseUrl != null ? '$_camBaseUrl/stream' : null;

  String? get cameraSnapshotUrl =>
      _camBaseUrl != null ? '$_camBaseUrl/api/v1/camera/snapshot' : null;

  /// Actually fetches a snapshot (not just resolves the URL) so a tap on
  /// "Snapshot" confirms the camera really responded.
  Future<void> fetchSnapshot() async {
    final url = cameraSnapshotUrl;
    if (url == null) {
      throw const ApiException('No camera IP set — add it in Settings.');
    }
    final res = await _client.get(Uri.parse(url)).timeout(_requestTimeout);
    if (res.statusCode >= 400) {
      throw ApiException('HTTP ${res.statusCode}', statusCode: res.statusCode);
    }
  }

  Future<void> setMic(bool on) async {
    final base = _camBaseUrl;
    if (base == null) return;
    await _camPost(base, '/api/v1/camera/mic', {'on': on});
  }

  Future<void> setNightVision(bool on) async {
    final base = _camBaseUrl;
    if (base == null) return;
    await _camPost(base, '/api/v1/camera/night_vision', {'on': on});
  }

  Future<CameraStatus> getCameraStatus() async {
    final base = _camBaseUrl;
    if (base == null) {
      throw const ApiException('No camera IP set — add it in Settings.');
    }
    final res = await _client
        .get(Uri.parse('$base/api/v1/camera/status'))
        .timeout(_requestTimeout);
    final json = _decode(res);
    return CameraStatus(
      signal: json['signal'] as String,
      lastSnapshotAt: json['last_snapshot_at'] != null
          ? DateTime.tryParse(json['last_snapshot_at'] as String)
          : null,
    );
  }

  Future<void> _camPost(
      String base, String path, Map<String, dynamic> body) async {
    try {
      await _client
          .post(Uri.parse('$base$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(_requestTimeout);
    } catch (_) {
      // The camera is best-effort from the app's UI — a dropped mic/night
      // toggle isn't worth surfacing as a hard error mid-stream.
    }
  }
}

class PairingStatus {
  final String state; // searching | found | failed
  final Device? device;
  const PairingStatus({required this.state, this.device});
}

class FeedJobStatus {
  final String status; // dispensing | done | error
  final int dispensedGrams;
  const FeedJobStatus({required this.status, required this.dispensedGrams});
}

class HistoryResponse {
  final List<DayIntake> bars;
  final List<FeedingEvent> events;
  const HistoryResponse({required this.bars, required this.events});
}

class CameraStatus {
  final String signal;
  final DateTime? lastSnapshotAt;
  const CameraStatus({required this.signal, this.lastSnapshotAt});
}
