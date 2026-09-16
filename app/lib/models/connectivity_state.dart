import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Mirrors the `connectivityState` demo enum wired into the .dc.html
/// prototype (Home screen banner + tab/button disabled states).
enum PpConnectivity {
  online,
  deviceOffline,
  sensorError,
  lowBattery,
  cloudUnreachable;

  static PpConnectivity fromWire(String value) {
    switch (value) {
      case 'device_offline':
        return PpConnectivity.deviceOffline;
      case 'sensor_error':
        return PpConnectivity.sensorError;
      case 'low_battery':
        return PpConnectivity.lowBattery;
      case 'cloud_unreachable':
        return PpConnectivity.cloudUnreachable;
      case 'online':
      default:
        return PpConnectivity.online;
    }
  }

  String get wire {
    switch (this) {
      case PpConnectivity.deviceOffline:
        return 'device_offline';
      case PpConnectivity.sensorError:
        return 'sensor_error';
      case PpConnectivity.lowBattery:
        return 'low_battery';
      case PpConnectivity.cloudUnreachable:
        return 'cloud_unreachable';
      case PpConnectivity.online:
        return 'online';
    }
  }
}

class ConnBanner {
  final Color bg;
  final Color fg;
  final String title;
  final String detail;
  const ConnBanner(this.bg, this.fg, this.title, this.detail);
}

/// `bannerMap` from the prototype's renderVals().
ConnBanner? bannerFor(PpConnectivity state) {
  switch (state) {
    case PpConnectivity.deviceOffline:
      return const ConnBanner(
        PpColors.neutral200,
        PpColors.neutral800,
        'Feeder is offline',
        'Last seen 22 minutes ago — check its power and Wi-Fi.',
      );
    case PpConnectivity.sensorError:
      return const ConnBanner(
        PpColors.accent100,
        PpColors.accent800,
        'Sensor error',
        'Bowl weight and food-level sensors aren’t reporting.',
      );
    case PpConnectivity.lowBattery:
      return const ConnBanner(
        PpColors.accent100,
        PpColors.accent800,
        'Power bank low — 8%',
        'Recharge soon to keep the feeder running.',
      );
    case PpConnectivity.cloudUnreachable:
      return const ConnBanner(
        PpColors.neutral200,
        PpColors.neutral800,
        'Can’t reach PetPulse cloud',
        'Showing the last data synced from your feeder.',
      );
    case PpConnectivity.online:
      return null;
  }
}
