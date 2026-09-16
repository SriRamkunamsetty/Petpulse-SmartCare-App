import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_entry.dart' show kWeekDays;
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/glass.dart';
import '../widgets/pp_button.dart';
import '../widgets/pp_card.dart';
import '../widgets/pp_motion.dart';
import 'ai_insights_screen.dart';
import 'sheets/alerts_sheet.dart';
import 'sheets/feed_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final greeting = _dayGreeting();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Hey, ${app.pet.name.isEmpty ? "there" : app.pet.name}',
                          style: ppHeading(size: 30)),
                      const SizedBox(height: 2),
                      Text(greeting,
                          style: ppBody(
                              size: 13,
                              color: PpColors.text.withValues(alpha: 0.55))),
                    ],
                  ),
                ),
                PpGlassButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiInsightsScreen()),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: Color(0xFF3A3632)),
                ),
                const SizedBox(width: 8),
                PpGlassButton(
                  onTap: () => openAlertsSheet(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          size: 18, color: Color(0xFF3A3632)),
                      if (app.hasUnreadAlerts)
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: PpColors.accent, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
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
                _CameraPreviewCard(
                    onTap: app.openCamera, offline: app.isDeviceOffline),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PpCard(
                        elevation: PpCardElevation.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PpCardKicker('Bowl'),
                            const SizedBox(height: 2),
                            app.isSensorError
                                ? Text('—', style: ppHeading(size: 26))
                                : PpAnimatedNumber(
                                    value: app.telemetry.bowlWeightGrams,
                                    builder: (context, v) => Text(
                                        '${v.toStringAsFixed(1)}g',
                                        style: ppHeading(size: 26)),
                                  ),
                            const SizedBox(height: 2),
                            PpCardMeta(app.isSensorError
                                ? 'Sensor error'
                                : 'Last refilled ${app.telemetry.lastRefilled}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PpCard(
                        elevation: PpCardElevation.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PpCardKicker('Food Level'),
                            const SizedBox(height: 2),
                            app.isSensorError
                                ? Text('—', style: ppHeading(size: 26))
                                : PpAnimatedNumber(
                                    value:
                                        app.telemetry.foodLevelPct.toDouble(),
                                    builder: (context, v) => Text(
                                        '${v.round()}%',
                                        style: ppHeading(size: 26)),
                                  ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                    begin: 0,
                                    end: (app.telemetry.foodLevelPct / 100)
                                        .clamp(0, 1)),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, _) =>
                                    LinearProgressIndicator(
                                  value: v,
                                  minHeight: 6,
                                  backgroundColor: PpColors.neutral300,
                                  valueColor: const AlwaysStoppedAnimation(
                                      PpColors.accent2_500),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PpCard(
                  elevation: PpCardElevation.sm,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PpCardKicker('Bowl Height'),
                          const SizedBox(height: 2),
                          app.isSensorError ||
                                  app.telemetry.bowlHeightCm == null
                              ? Text('—', style: ppHeading(size: 17))
                              : PpAnimatedNumber(
                                  value: app.telemetry.bowlHeightCm!,
                                  builder: (context, v) => Text(
                                      '${v.toStringAsFixed(1)} cm',
                                      style: ppHeading(size: 17)),
                                ),
                          const PpCardMeta(
                              'Ultrasonic distance to bowl surface'),
                        ],
                      ),
                      const Icon(Icons.straighten_rounded,
                          color: PpColors.accent700),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PpCard(
                  elevation: PpCardElevation.sm,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PpCardKicker('Next Feeding'),
                          const SizedBox(height: 2),
                          Builder(builder: (context) {
                            final next = app.nextFeeding;
                            if (next == null) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('No upcoming feedings',
                                      style: ppHeading(size: 17)),
                                  const SizedBox(width: 6),
                                  PawMascot(
                                      size: 16,
                                      color: PpColors.text
                                          .withValues(alpha: 0.35)),
                                ],
                              );
                            }
                            final today = kWeekDays[DateTime.now().weekday - 1];
                            final dayPrefix =
                                next.day == today ? '' : '${next.day} ';
                            return Text(
                                '$dayPrefix${next.time} · ${next.grams}g',
                                style: ppHeading(size: 17));
                          }),
                        ],
                      ),
                      const Icon(Icons.schedule_rounded,
                          color: PpColors.accent700),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PpButton(
                  label: app.isDeviceOffline
                      ? 'Feeder Offline'
                      : 'Feed ${app.pet.name.isEmpty ? "Pet" : app.pet.name} Now',
                  height: 52,
                  onPressed:
                      app.isDeviceOffline ? null : () => openFeedSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dayGreeting() => "Here's how today is going";
}

class _CameraPreviewCard extends StatelessWidget {
  const _CameraPreviewCard({required this.onTap, required this.offline});
  final VoidCallback onTap;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return PpCard(
      elevation: PpCardElevation.md,
      color: PpColors.accent800,
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.4, -0.6),
                        colors: [Color(0xFF4A4038), Color(0xFF211D18)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PpDot(
                              color: offline
                                  ? PpColors.neutral500
                                  : PpColors.liveRed,
                              size: 6),
                          const SizedBox(width: 5),
                          Text(
                            offline ? 'OFFLINE' : 'LIVE',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Feeder Cam',
                      style: ppHeading(size: 15, color: Colors.white)),
                  Text('Kitchen · ESP32-CAM',
                      style: ppBody(
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(offline ? 'Offline' : 'Online',
                    style: ppBody(
                        size: 11,
                        weight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
