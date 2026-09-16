import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/alert_item.dart';

/// Local (on-device) notifications for alerts — fired the moment `AppState`
/// sees a new unread [AlertItem] from the server. Real push delivery while
/// the app is fully closed needs FCM/APNs wired server-side; see
/// docs/API_CONTRACT.md.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  Future<void> notifyAlert(AlertItem alert) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      'petpulse_alerts',
      'PetPulse Alerts',
      channelDescription: 'Feeding, device and sensor alerts from PetPulse',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.show(
      alert.id.hashCode,
      alert.title,
      alert.detail,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
