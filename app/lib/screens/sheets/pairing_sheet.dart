import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/pp_button.dart';
import '../../widgets/pp_sheet.dart';

Future<void> openDevicePairingSheet(BuildContext context) async {
  final app = context.read<AppState>();
  await app.openPairing();
  if (!context.mounted) return;
  await showPpSheet(context, builder: (_) => const _PairingContent());
  app.closeSheet();
}

class _PairingContent extends StatelessWidget {
  const _PairingContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        return Column(
          children: switch (app.settingsPairState) {
            SettingsPairState.idle || SettingsPairState.searching => [
                const SizedBox(height: 10),
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                      strokeWidth: 4, color: PpColors.accent),
                ),
                const SizedBox(height: 18),
                Text('Searching…', style: ppHeading(size: 18)),
                const SizedBox(height: 4),
                Text('Looking for nearby PetPulse devices',
                    style: ppBody(
                        size: 13, color: Colors.black.withValues(alpha: 0.6))),
              ],
            SettingsPairState.found => [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                      color: PpColors.accent100, shape: BoxShape.circle),
                  child: const Icon(Icons.router_rounded,
                      color: PpColors.accent700),
                ),
                const SizedBox(height: 14),
                Text('${app.settingsPairedDevice?.name ?? "New device"} found',
                    style: ppHeading(size: 18)),
                const SizedBox(height: 4),
                Text('A new device on your network',
                    textAlign: TextAlign.center,
                    style: ppBody(
                        size: 13, color: Colors.black.withValues(alpha: 0.6))),
                const SizedBox(height: 18),
                PpButton(
                    label: 'Connect', onPressed: app.confirmSettingsPairing),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel',
                      style: ppBody(size: 14, color: PpColors.accent)),
                ),
              ],
            SettingsPairState.connected => [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: PpColors.accent2_100, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: PpColors.accent2_700, size: 28),
                ),
                const SizedBox(height: 14),
                Text('Connected', style: ppHeading(size: 18)),
                const SizedBox(height: 4),
                Text('Device paired successfully',
                    style: ppBody(
                        size: 13, color: Colors.black.withValues(alpha: 0.6))),
                const SizedBox(height: 18),
                PpButton(
                    label: 'Done',
                    onPressed: () => Navigator.of(context).pop()),
              ],
          },
        );
      },
    );
  }
}
