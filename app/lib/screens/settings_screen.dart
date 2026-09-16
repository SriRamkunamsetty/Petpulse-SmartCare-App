import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../services/api_service.dart';
import '../services/wifi_info_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/pp_button.dart';
import '../widgets/pp_card.dart';
import 'sheets/pairing_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Text('Settings', style: ppHeading(size: 30)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HubConnectionCard(),
                const SizedBox(height: 20),
                const _CamConnectionCard(),
                const SizedBox(height: 20),
                const PpCardKicker('Devices'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: PpColors.surface,
                    borderRadius: BorderRadius.circular(PpRadius.md),
                    boxShadow: PpShadow.sm,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < app.devices.length; i++)
                        _DeviceRow(
                            device: app.devices[i],
                            showDivider: i < app.devices.length - 1),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                PpButton(
                  label: '+ Add Device',
                  variant: PpButtonVariant.secondary,
                  height: 44,
                  onPressed: () => openDevicePairingSheet(context),
                ),
                const SizedBox(height: 20),
                const PpCardKicker('Pet Profile'),
                const SizedBox(height: 8),
                PpCard(
                  elevation: PpCardElevation.sm,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: PpColors.accent2_500,
                            shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(app.pet.initial,
                            style: ppHeading(size: 17, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.pet.name.isEmpty ? '—' : app.pet.name,
                              style: ppHeading(size: 17)),
                          PpCardMeta(app.pet.breedWeightLine),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const PpCardKicker('Preferences'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: PpColors.surface,
                    borderRadius: BorderRadius.circular(PpRadius.md),
                    boxShadow: PpShadow.sm,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _PrefRow(
                        label: 'Units',
                        trailing: PpSegmented(
                          options: const ['g', 'oz'],
                          value: app.units,
                          onChanged: app.setUnits,
                        ),
                        showDivider: true,
                      ),
                      _PrefRow(
                        label: 'Push Notifications',
                        trailing: PpSwitch(
                            value: app.notifsOn,
                            onChanged: (_) => app.toggleNotifs()),
                        showDivider: true,
                      ),
                      const _PrefRow(
                        label: 'Wi-Fi Network',
                        trailing: _WifiNetworkLabel(),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const PpCardKicker('About'),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: PpColors.surface,
                    borderRadius: BorderRadius.circular(PpRadius.md),
                    boxShadow: PpShadow.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Version',
                          style: ppBody(size: 14, weight: FontWeight.w600)),
                      Text('1.0.0',
                          style: ppBody(
                              size: 13,
                              color: PpColors.text.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow(
      {required this.label, required this.trailing, required this.showDivider});
  final String label;
  final Widget trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: PpColors.divider))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ppBody(size: 14, weight: FontWeight.w600)),
          trailing,
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.showDivider});
  final Device device;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final (tagLabel, variant) = switch (device.status) {
      DeviceStatus.offline => ('Offline', PpTagVariant.neutral),
      DeviceStatus.lowBattery => ('Low battery', PpTagVariant.accent),
      DeviceStatus.online => ('Online', PpTagVariant.accent2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: PpColors.divider))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                color: PpColors.accent100, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(_shortCode(device.kind),
                style: ppBody(
                    size: 10,
                    weight: FontWeight.w700,
                    color: PpColors.accent800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name,
                    style: ppBody(size: 14, weight: FontWeight.w700)),
                PpCardMeta(device.meta.isEmpty
                    ? _kindLabel(device.kind)
                    : device.meta),
              ],
            ),
          ),
          PpTag(tagLabel, variant: variant),
        ],
      ),
    );
  }

  String _shortCode(DeviceKind kind) => switch (kind) {
        DeviceKind.hub => 'S3',
        DeviceKind.cam => 'CAM',
        DeviceKind.loadCell => 'LC',
        DeviceKind.ultrasonic => 'US',
      };

  String _kindLabel(DeviceKind kind) => switch (kind) {
        DeviceKind.hub => 'Controller',
        DeviceKind.cam => 'Live video',
        DeviceKind.loadCell => 'Bowl weight sensor',
        DeviceKind.ultrasonic => 'Food-level sensor',
      };
}

/// Lets the user point the app at a real ESP32-S3 hub's local IP.
///
/// There's no discovery/pairing for this yet — `esp32s3_hub.ino` doesn't
/// implement the pairing endpoints (see firmware/README.md) — so this is
/// the fast path: read the IP off the hub's own Serial Monitor after it
/// joins Wi-Fi, type it in here. Once saved, `ApiService._resolveBaseUrl()`
/// tries it first on every request automatically.
class _HubConnectionCard extends StatefulWidget {
  const _HubConnectionCard();

  @override
  State<_HubConnectionCard> createState() => _HubConnectionCardState();
}

class _HubConnectionCardState extends State<_HubConnectionCard> {
  late final TextEditingController _controller;
  bool _testing = false;
  bool? _lastResult;

  @override
  void initState() {
    super.initState();
    final saved = context.read<ApiService>().localBaseUrl;
    final ip = saved != null ? saved.replaceFirst('http://', '') : '';
    _controller = TextEditingController(text: ip);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final ip = _controller.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _testing = true;
      _lastResult = null;
    });
    final api = context.read<ApiService>();
    final ok = await api.testLocalHub(ip);
    if (ok) {
      await api.setLocalHubIp(ip);
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _lastResult = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PpCardKicker('Feeder Hub'),
        const SizedBox(height: 8),
        PpCard(
          elevation: PpCardElevation.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PpInput(
                label: 'Hub IP address',
                controller: _controller,
                placeholder: 'e.g. 192.168.1.42',
              ),
              const SizedBox(height: 4),
              Text(
                "Find this on the ESP32-S3's Serial Monitor after it joins "
                'Wi-Fi ("Connected. IP address: ...").',
                style: ppBody(
                    size: 11, color: PpColors.text.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 12),
              PpButton(
                label: _testing ? 'Connecting…' : 'Connect',
                height: 42,
                onPressed: _testing ? null : _connect,
              ),
              if (_lastResult != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _lastResult!
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 16,
                      color: _lastResult!
                          ? PpColors.accent2_700
                          : PpColors.accent700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _lastResult!
                            ? 'Connected — the app will use this hub for live sensor data and feeding.'
                            : "Couldn't reach that IP. Check the hub is powered on, on the same Wi-Fi, and the IP is correct.",
                        style: ppBody(
                          size: 12,
                          color: _lastResult!
                              ? PpColors.accent2_700
                              : PpColors.accent700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Same idea as [_HubConnectionCard] but for the ESP32-CAM — a physically
/// separate board with its own IP (see firmware/esp32_cam/esp32_cam.ino).
class _CamConnectionCard extends StatefulWidget {
  const _CamConnectionCard();

  @override
  State<_CamConnectionCard> createState() => _CamConnectionCardState();
}

class _CamConnectionCardState extends State<_CamConnectionCard> {
  late final TextEditingController _controller;
  bool _testing = false;
  bool? _lastResult;

  @override
  void initState() {
    super.initState();
    final saved = context.read<ApiService>().camBaseUrl;
    final ip = saved != null ? saved.replaceFirst('http://', '') : '';
    _controller = TextEditingController(text: ip);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final ip = _controller.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _testing = true;
      _lastResult = null;
    });
    final api = context.read<ApiService>();
    final ok = await api.testLocalCam(ip);
    if (ok) {
      await api.setLocalCamIp(ip);
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _lastResult = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PpCardKicker('Feeder Cam'),
        const SizedBox(height: 8),
        PpCard(
          elevation: PpCardElevation.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PpInput(
                label: 'Camera IP address',
                controller: _controller,
                placeholder: 'e.g. 192.168.1.55',
              ),
              const SizedBox(height: 4),
              Text(
                "Find this on the ESP32-CAM's Serial Monitor after it joins "
                'Wi-Fi. This is a separate board from the hub.',
                style: ppBody(
                    size: 11, color: PpColors.text.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 12),
              PpButton(
                label: _testing ? 'Connecting…' : 'Connect',
                height: 42,
                onPressed: _testing ? null : _connect,
              ),
              if (_lastResult != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _lastResult!
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 16,
                      color: _lastResult!
                          ? PpColors.accent2_700
                          : PpColors.accent700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _lastResult!
                            ? 'Connected — open the Camera tab for the live feed.'
                            : "Couldn't reach that IP. Check the camera is powered on, on the same Wi-Fi, and the IP is correct.",
                        style: ppBody(
                          size: 12,
                          color: _lastResult!
                              ? PpColors.accent2_700
                              : PpColors.accent700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The phone's actual connected Wi-Fi name (not the hub's or camera's —
/// see WifiInfoService's doc comment). Tap to retry if permission was
/// denied or the OS hasn't reported it yet.
class _WifiNetworkLabel extends StatefulWidget {
  const _WifiNetworkLabel();

  @override
  State<_WifiNetworkLabel> createState() => _WifiNetworkLabelState();
}

class _WifiNetworkLabelState extends State<_WifiNetworkLabel> {
  final _service = WifiInfoService();
  WifiInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final info = await _service.getSsid();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 14,
        height: 14,
        child:
            CircularProgressIndicator(strokeWidth: 2, color: PpColors.accent),
      );
    }
    final info = _info;
    final label = switch (info?.result) {
      WifiInfoResult.ok => info!.ssid!,
      WifiInfoResult.permissionDenied => 'Permission needed',
      _ => 'Unavailable',
    };
    return InkWell(
      onTap: _load,
      child: Text(label,
          style: ppBody(size: 13, color: PpColors.text.withValues(alpha: 0.5))),
    );
  }
}
