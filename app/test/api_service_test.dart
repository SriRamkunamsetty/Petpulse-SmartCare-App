// Integration test against the reference server in mock_server/.
// Requires it running locally first:
//   cd mock_server && npm install && npm start
// Then: flutter test test/api_service_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petpulse/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test blocks real HTTP by default (returns 400 for everything) to
  // stop accidental network calls in unit tests. This suite's whole point is
  // to hit the real mock_server, so opt back into real networking.
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  late ApiService api;

  setUp(() async {
    api = ApiService();
    await api.setCloudBaseUrl('http://localhost:4000');
  });

  test('full contract walkthrough against mock_server', () async {
    await api.register(
        'test-${DateTime.now().millisecondsSinceEpoch}@petpulse.local',
        'password123');
    expect(api.hasToken, isTrue);

    final pet = await api.getPet();
    expect(pet.name, 'Milo');

    final saved = await api.savePet(pet.copyWith(name: 'Rex'));
    expect(saved.name, 'Rex');

    final devices = await api.getDevices();
    expect(devices, isNotEmpty);

    final sessionId = await api.startPairing();
    PairingStatus status;
    do {
      await Future.delayed(const Duration(milliseconds: 300));
      status = await api.getPairingStatus(sessionId);
    } while (status.state == 'searching');
    expect(status.state, 'found');
    expect(status.device, isNotNull);

    final confirmed = await api.confirmPairing(sessionId);
    expect(confirmed.id, status.device!.id);

    final telemetry = await api.getTelemetry();
    expect(telemetry.bowlWeightGrams, greaterThanOrEqualTo(0));

    final jobId = await api.startManualFeed(45);
    FeedJobStatus jobStatus;
    do {
      await Future.delayed(const Duration(milliseconds: 200));
      jobStatus = await api.getFeedJobStatus(jobId);
    } while (jobStatus.status == 'dispensing');
    expect(jobStatus.status, 'done');
    expect(jobStatus.dispensedGrams, 45);

    final schedule = await api.getSchedule();
    expect(schedule, isNotEmpty);
    final newEntry = await api.addScheduleEntry('Wed', '3:00 PM', 30);
    await api.setScheduleEnabled(newEntry.id, false);
    await api.deleteScheduleEntry(newEntry.id);

    final history = await api.getHistory();
    expect(history.bars, hasLength(7));

    final alerts = await api.getAlerts();
    expect(alerts, isNotEmpty);
    await api.markAlertRead(alerts.first.id);

    // Camera endpoints target a separate device's own IP — point it at
    // mock_server itself here, since mock_server also implements the
    // camera routes (see mock_server/camera.js) as a stand-in cam.
    await api.setLocalCamIp('localhost:4000');
    expect(api.cameraSnapshotUrl, contains('/api/v1/camera/snapshot'));
    expect(api.cameraStreamUrl, contains('/stream'));
    await api.fetchSnapshot();
    await api.setMic(true);
    await api.setNightVision(true);
    final camStatus = await api.getCameraStatus();
    expect(camStatus.signal, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
