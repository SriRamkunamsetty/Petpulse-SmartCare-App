import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_item.dart';
import '../models/connectivity_state.dart';
import '../models/device.dart';
import '../models/feeding_event.dart';
import '../models/pet.dart';
import '../models/schedule_entry.dart';
import '../models/telemetry.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/polling_service.dart';
import '../utils/time_format.dart';

enum AppSheet { none, feed, alerts, addSchedule, pairing }

enum FeedStage { confirm, feeding, done }

enum SettingsPairState { idle, searching, found, connected }

/// App-wide state: pet profile, devices, schedule, telemetry, alerts, and
/// every interactive flow (manual feed, add-schedule, camera controls,
/// device pairing from Settings) — each one now backed by a real call to
/// [ApiService] instead of the prototype's `setState`/`setTimeout`.
class AppState extends ChangeNotifier {
  AppState(this._api) : _polling = PollingService(_api) {
    _api.isWakingCloud.addListener(_onCloudWakingChanged);
  }

  final ApiService _api;
  final PollingService _polling;
  final _notifications = NotificationService();
  StreamSubscription<Telemetry>? _telemetrySub;

  bool bootstrapping = true;
  bool onboarded = false;
  String? bootstrapError;

  /// Mirrors [ApiService.isWakingCloud] — true while a cloud request is
  /// being retried after an initial timeout, most likely a free-tier host
  /// waking from an idle sleep. The bootstrap screen (main.dart) and Home
  /// screen use this to show a "waking up" message instead of an error.
  bool get isWakingCloud => _api.isWakingCloud.value;
  void _onCloudWakingChanged() => notifyListeners();

  Pet pet = Pet.empty;
  List<Device> devices = [];
  List<ScheduleEntry> schedule = [];
  List<AlertItem> alerts = [];
  Telemetry telemetry = Telemetry.placeholder();
  List<DayIntake> weekBars = [];
  List<FeedingEvent> historyEvents = [];

  String activeTab = 'home';
  AppSheet sheet = AppSheet.none;
  String selectedDay = kWeekDays[max(0, DateTime.now().weekday - 1)];

  // Manual feed sheet
  FeedStage feedStage = FeedStage.confirm;
  int manualPortion = 45;
  int feedCurrentGrams = 0;
  Timer? _feedPollTimer;

  // Add-schedule sheet
  String addTime = '7:00 AM';
  int addPortion = 40;
  final Set<String> addDays = {};

  // Camera
  bool micOn = false;
  bool nightVisionOn = false;
  bool snapshotFlash = false;
  String lastSnapshot = '—';

  // Settings
  String units = 'g';
  bool notifsOn = true;

  // Settings > Add Device pairing
  SettingsPairState settingsPairState = SettingsPairState.idle;
  Device? settingsPairedDevice;
  String? _settingsPairSessionId;
  Timer? _settingsPairTimer;

  bool get hasUnreadAlerts => alerts.any((a) => !a.read);
  bool get isDeviceOffline =>
      telemetry.connectivity == PpConnectivity.deviceOffline;
  bool get isSensorError =>
      telemetry.connectivity == PpConnectivity.sensorError;
  ConnBanner? get connectivityBanner => bannerFor(telemetry.connectivity);

  List<ScheduleEntry> get scheduleForSelectedDay =>
      schedule.where((e) => e.day == selectedDay).toList();

  /// The next enabled schedule entry after right now, wrapping the week if
  /// needed — computed from [schedule] instead of trusting the hub's
  /// `next_feed_time`/`next_feed_grams` (the hub doesn't know the
  /// schedule; only the app/relay stores it). Recomputes on every call, so
  /// it stays correct as time passes and updates the moment a feed
  /// happens to push the "today" cutoff forward.
  ({String day, String time, int grams})? get nextFeeding {
    final enabled = schedule.where((e) => e.enabled).toList();
    if (enabled.isEmpty) return null;
    final now = DateTime.now();
    final todayIndex = now.weekday - 1; // DateTime: Mon=1..Sun=7 -> 0..6
    final nowMinutes = now.hour * 60 + now.minute;
    for (var offset = 0; offset < 7; offset++) {
      final day = kWeekDays[(todayIndex + offset) % 7];
      final candidates = enabled.where((e) => e.day == day).toList()
        ..sort((a, b) => (parseTimeToMinutes(a.time) ?? 0)
            .compareTo(parseTimeToMinutes(b.time) ?? 0));
      for (final entry in candidates) {
        final minutes = parseTimeToMinutes(entry.time);
        if (minutes == null) continue;
        // Already passed today — wait for the next occurrence.
        if (offset == 0 && minutes <= nowMinutes) continue;
        return (day: day, time: entry.time, grams: entry.grams);
      }
    }
    return null;
  }

  Future<void> bootstrap() async {
    bootstrapping = true;
    notifyListeners();
    try {
      await _api.restoreSession();
      final prefs = await SharedPreferences.getInstance();
      if (!_api.hasToken) {
        // The design has no login screen — the app authenticates itself
        // with a per-install anonymous account on first launch so every
        // call in docs/API_CONTRACT.md still goes through a real,
        // authorized backend.
        final rand = Random.secure();
        final suffix =
            List.generate(12, (_) => rand.nextInt(16).toRadixString(16)).join();
        final email = 'device-$suffix@petpulse.local';
        final password =
            List.generate(20, (_) => rand.nextInt(16).toRadixString(16)).join();
        await _api.register(email, password);
        await prefs.setString('pp_anon_email', email);
      }
      onboarded = prefs.getBool('pp_onboarded') ?? false;
      units = prefs.getString('pp_units') ?? 'g';
      notifsOn = prefs.getBool('pp_notifs_on') ?? true;
      await _notifications.init();

      if (onboarded) {
        await _loadAll();
        _startPolling();
      }
      bootstrapError = null;
    } on ApiException catch (e) {
      bootstrapError = e.message;
    } finally {
      bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _api.getPet(),
      _api.getDevices(),
      _api.getSchedule(),
      _api.getAlerts(),
      _api.getHistory(),
    ]);
    pet = results[0] as Pet;
    devices = results[1] as List<Device>;
    schedule = results[2] as List<ScheduleEntry>;
    final newAlerts = results[3] as List<AlertItem>;
    _notifyNewAlerts(previous: alerts, next: newAlerts);
    alerts = newAlerts;
    final history = results[4] as HistoryResponse;
    weekBars = history.bars;
    historyEvents = history.events;
    notifyListeners();
  }

  void _notifyNewAlerts(
      {required List<AlertItem> previous, required List<AlertItem> next}) {
    if (!notifsOn) return;
    final previousIds = previous.map((a) => a.id).toSet();
    for (final alert in next) {
      if (!alert.read && !previousIds.contains(alert.id)) {
        _notifications.notifyAlert(alert);
      }
    }
  }

  void _startPolling() {
    _telemetrySub?.cancel();
    _telemetrySub = _polling.stream.listen((t) {
      telemetry = t;
      notifyListeners();
    });
    _polling.start();
  }

  void setFastPolling(bool fast) => _polling.setFastMode(fast);

  Future<void> refreshAlerts() async {
    try {
      final newAlerts = await _api.getAlerts();
      _notifyNewAlerts(previous: alerts, next: newAlerts);
      alerts = newAlerts;
      notifyListeners();
    } on ApiException {
      // Alerts are non-critical; a poll failure here is already surfaced
      // via the telemetry connectivity banner.
    }
  }

  // ── Onboarding completion ───────────────────────────────────────────
  Future<void> finishOnboarding(Pet newPet) async {
    pet = await _api.savePet(newPet);
    onboarded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pp_onboarded', true);
    await _loadAll();
    _startPolling();
    notifyListeners();
  }

  // ── Navigation ──────────────────────────────────────────────────────
  void goTab(String tab) {
    activeTab = tab;
    sheet = AppSheet.none;
    setFastPolling(tab == 'home' || tab == 'camera');
    notifyListeners();
  }

  void closeSheet() {
    _feedPollTimer?.cancel();
    sheet = AppSheet.none;
    notifyListeners();
  }

  // ── Manual feed ─────────────────────────────────────────────────────
  void openFeedSheet() {
    sheet = AppSheet.feed;
    feedStage = FeedStage.confirm;
    feedCurrentGrams = 0;
    notifyListeners();
  }

  void incPortion() {
    manualPortion = (manualPortion + 5).clamp(10, 120);
    notifyListeners();
  }

  void decPortion() {
    manualPortion = (manualPortion - 5).clamp(10, 120);
    notifyListeners();
  }

  Future<void> startFeeding() async {
    feedStage = FeedStage.feeding;
    feedCurrentGrams = 0;
    notifyListeners();
    try {
      final jobId = await _api.startManualFeed(manualPortion);
      _feedPollTimer?.cancel();
      _feedPollTimer =
          Timer.periodic(const Duration(milliseconds: 180), (_) async {
        try {
          final status = await _api.getFeedJobStatus(jobId);
          feedCurrentGrams = status.dispensedGrams;
          if (status.status == 'done' || status.status == 'error') {
            _feedPollTimer?.cancel();
            feedStage = FeedStage.done;
            unawaited(_refreshTelemetryOnce());
          }
          notifyListeners();
        } on ApiException {
          _feedPollTimer?.cancel();
          feedStage = FeedStage.done;
          notifyListeners();
        }
      });
    } on ApiException {
      feedStage = FeedStage.done;
      notifyListeners();
    }
  }

  Future<void> _refreshTelemetryOnce() async {
    try {
      telemetry = await _api.getTelemetry();
      notifyListeners();
    } on ApiException {
      // Next scheduled poll will retry.
    }
  }

  // ── Alerts ──────────────────────────────────────────────────────────
  Future<void> openAlerts() async {
    sheet = AppSheet.alerts;
    notifyListeners();
    final unread = alerts.where((a) => !a.read).toList();
    for (final a in unread) {
      try {
        await _api.markAlertRead(a.id);
      } on ApiException {
        // Best-effort — local badge will just re-show next refresh.
      }
    }
    if (unread.isNotEmpty) {
      alerts = alerts
          .map((a) => a.read
              ? a
              : AlertItem(
                  id: a.id,
                  title: a.title,
                  detail: a.detail,
                  timestamp: a.timestamp,
                  severity: a.severity,
                  read: true,
                ))
          .toList();
      notifyListeners();
    }
  }

  void openCamera() => goTab('camera');

  // ── Schedule ────────────────────────────────────────────────────────
  void selectDay(String day) {
    selectedDay = day;
    notifyListeners();
  }

  Future<void> toggleScheduleItem(ScheduleEntry entry) async {
    final newEnabled = !entry.enabled;
    schedule = schedule
        .map((e) => e.id == entry.id ? e.copyWith(enabled: newEnabled) : e)
        .toList();
    notifyListeners();
    try {
      await _api.setScheduleEnabled(entry.id, newEnabled);
    } on ApiException {
      // Roll back on failure.
      schedule = schedule
          .map((e) => e.id == entry.id ? e.copyWith(enabled: !newEnabled) : e)
          .toList();
      notifyListeners();
    }
  }

  void openAddSchedule() {
    sheet = AppSheet.addSchedule;
    addTime = '7:00 AM';
    addPortion = 40;
    addDays
      ..clear()
      ..add(selectedDay);
    notifyListeners();
  }

  void toggleAddDay(String day) {
    if (addDays.contains(day)) {
      addDays.remove(day);
    } else {
      addDays.add(day);
    }
    notifyListeners();
  }

  void incAddPortion() {
    addPortion = (addPortion + 5).clamp(10, 150);
    notifyListeners();
  }

  void decAddPortion() {
    addPortion = (addPortion - 5).clamp(10, 150);
    notifyListeners();
  }

  void setAddTime(String v) {
    addTime = v;
    notifyListeners();
  }

  Future<void> saveSchedule() async {
    final days = addDays.toList();
    sheet = AppSheet.none;
    notifyListeners();
    for (final day in days) {
      try {
        final entry = await _api.addScheduleEntry(day, addTime, addPortion);
        schedule = [...schedule, entry];
      } on ApiException {
        // Skip the day that failed; the rest still get saved.
      }
    }
    notifyListeners();
  }

  // ── Camera ──────────────────────────────────────────────────────────
  Future<void> toggleMic() async {
    micOn = !micOn;
    notifyListeners();
    try {
      await _api.setMic(micOn);
    } on ApiException {
      micOn = !micOn;
      notifyListeners();
    }
  }

  Future<void> toggleNightVision() async {
    nightVisionOn = !nightVisionOn;
    notifyListeners();
    try {
      await _api.setNightVision(nightVisionOn);
    } on ApiException {
      nightVisionOn = !nightVisionOn;
      notifyListeners();
    }
  }

  Future<void> takeSnapshot() async {
    snapshotFlash = true;
    notifyListeners();
    try {
      await _api.fetchSnapshot();
      lastSnapshot = 'Just now';
    } on ApiException {
      // Leave lastSnapshot as-is if the request failed.
    }
    await Future.delayed(const Duration(milliseconds: 150));
    snapshotFlash = false;
    notifyListeners();
  }

  // ── Settings ────────────────────────────────────────────────────────
  Future<void> setUnits(String u) async {
    units = u;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pp_units', u);
  }

  Future<void> toggleNotifs() async {
    notifsOn = !notifsOn;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pp_notifs_on', notifsOn);
  }

  Future<void> openPairing() async {
    sheet = AppSheet.pairing;
    settingsPairState = SettingsPairState.searching;
    settingsPairedDevice = null;
    notifyListeners();
    try {
      _settingsPairSessionId = await _api.startPairing();
      _settingsPairTimer?.cancel();
      _settingsPairTimer =
          Timer.periodic(const Duration(milliseconds: 700), (_) async {
        final sessionId = _settingsPairSessionId;
        if (sessionId == null) return;
        try {
          final status = await _api.getPairingStatus(sessionId);
          if (status.state == 'found' && status.device != null) {
            _settingsPairTimer?.cancel();
            settingsPairedDevice = status.device;
            settingsPairState = SettingsPairState.found;
            notifyListeners();
          }
        } on ApiException {
          _settingsPairTimer?.cancel();
        }
      });
    } on ApiException {
      // Leave in searching state; user can close the sheet and retry.
    }
  }

  Future<void> confirmSettingsPairing() async {
    final sessionId = _settingsPairSessionId;
    if (sessionId == null) return;
    try {
      final device = await _api.confirmPairing(sessionId);
      settingsPairedDevice = device;
      settingsPairState = SettingsPairState.connected;
      devices = await _api.getDevices();
      notifyListeners();
    } on ApiException {
      // Stay on the "found" screen so the user can retry Connect.
    }
  }

  @override
  void dispose() {
    _api.isWakingCloud.removeListener(_onCloudWakingChanged);
    _telemetrySub?.cancel();
    _polling.dispose();
    _feedPollTimer?.cancel();
    _settingsPairTimer?.cancel();
    super.dispose();
  }
}
