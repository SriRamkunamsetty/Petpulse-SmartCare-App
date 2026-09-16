import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/glass.dart';
import '../widgets/mjpeg_view.dart';
import '../widgets/pp_card.dart';
import '../widgets/pp_motion.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Bumping this forces MjpegView to tear down and reconnect on "Snapshot"/
  // retry taps, even when the URL string itself hasn't changed.
  int _streamGeneration = 0;

  void _retry() => setState(() => _streamGeneration++);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final api = context.watch<ApiService>();
    final streamUrl = api.cameraStreamUrl;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Camera', style: ppHeading(size: 30)),
                const SizedBox(height: 2),
                Text('ESP32-CAM · Kitchen',
                    style: ppBody(
                        size: 13,
                        color: PpColors.text.withValues(alpha: 0.55))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (app.connectivityBanner != null) ...[
                  ConnectivityBanner(banner: app.connectivityBanner!),
                  const SizedBox(height: 14),
                ],
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PpRadius.lg),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(-0.4, -0.6),
                          colors: [Color(0xFF4A4038), Color(0xFF211D18)],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: streamUrl == null
                                ? _NoCameraMessage(onRetry: _retry)
                                : MjpegView(
                                    key: ValueKey(
                                        '$streamUrl#$_streamGeneration'),
                                    url: streamUrl,
                                  ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PpDot(
                                      color: streamUrl == null
                                          ? PpColors.neutral500
                                          : PpColors.liveRed,
                                      size: 6),
                                  const SizedBox(width: 5),
                                  Text(streamUrl == null ? 'OFFLINE' : 'LIVE',
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.7,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text('720p',
                                  style: TextStyle(
                                      fontSize: 10.5, color: Colors.white)),
                            ),
                          ),
                          if (app.snapshotFlash)
                            Positioned.fill(
                                child: Container(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CamAction(
                      icon: Icons.camera_alt_rounded,
                      label: 'Snapshot',
                      onTap: () {
                        app.takeSnapshot();
                        _retry();
                      },
                    ),
                    const SizedBox(width: 16),
                    _CamAction(
                      icon: app.micOn
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      label: app.micOn ? 'Mic on' : 'Mic off',
                      tint: app.micOn ? PpColors.accent2_200 : null,
                      onTap: app.toggleMic,
                    ),
                    const SizedBox(width: 16),
                    _CamAction(
                      icon: Icons.nightlight_round,
                      label: app.nightVisionOn ? 'Night on' : 'Night vision',
                      tint: app.nightVisionOn ? PpColors.accent2_200 : null,
                      onTap: app.toggleNightVision,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PpCard(
                  elevation: PpCardElevation.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PpCardKicker('Connection'),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Signal strength', style: ppBody(size: 13)),
                          Text(streamUrl == null ? 'Not connected' : 'Strong',
                              style: ppBody(size: 13, weight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Last snapshot', style: ppBody(size: 13)),
                          Text(app.lastSnapshot,
                              style: ppBody(size: 13, weight: FontWeight.w700)),
                        ],
                      ),
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

class _CamAction extends StatelessWidget {
  const _CamAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.tint});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PpGlassButton(
            size: 48,
            onTap: onTap,
            tint: tint,
            child: Icon(icon, size: 19, color: const Color(0xFF3A3632))),
        const SizedBox(height: 6),
        Text(label,
            style:
                ppBody(size: 10, color: PpColors.text.withValues(alpha: 0.55))),
      ],
    );
  }
}

class _NoCameraMessage extends StatelessWidget {
  const _NoCameraMessage({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PawMascot(size: 32, color: Colors.white38),
          const SizedBox(height: 8),
          const Text('Camera not connected',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text('Add its IP in Settings → Feeder Cam',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
