import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum WifiInfoResult { ok, permissionDenied, unavailable }

class WifiInfo {
  final WifiInfoResult result;
  final String? ssid;
  const WifiInfo(this.result, this.ssid);
}

/// Reads the phone's actual connected Wi-Fi network name — not the hub's
/// or camera's network (those are configured separately, see
/// firmware/README.md), this is what the phone itself is on, shown in
/// Settings so "Wi-Fi Network" stops being a hardcoded "Home_5G".
///
/// Platform notes:
/// - Android: reading the real SSID requires location permission (an OS
///   privacy restriction on SSID access, not a PetPulse choice) — this
///   requests it if not already granted.
/// - iOS: real SSID access requires the "Access WiFi Information"
///   capability, which needs a paid Apple Developer account entitlement
///   added in Xcode. Without it, iOS returns null and this falls back to
///   "Connected" (no name) rather than failing.
class WifiInfoService {
  final _networkInfo = NetworkInfo();

  Future<WifiInfo> getSsid() async {
    if (Platform.isAndroid) {
      final status = await Permission.locationWhenInUse.status;
      if (!status.isGranted) {
        final requested = await Permission.locationWhenInUse.request();
        if (!requested.isGranted) {
          return const WifiInfo(WifiInfoResult.permissionDenied, null);
        }
      }
    }
    try {
      final raw = await _networkInfo.getWifiName();
      // Android/iOS both sometimes wrap the SSID in quotes.
      final ssid = raw?.replaceAll('"', '').trim();
      if (ssid == null || ssid.isEmpty || ssid == '<unknown ssid>') {
        return const WifiInfo(WifiInfoResult.unavailable, null);
      }
      return WifiInfo(WifiInfoResult.ok, ssid);
    } catch (_) {
      return const WifiInfo(WifiInfoResult.unavailable, null);
    }
  }
}
