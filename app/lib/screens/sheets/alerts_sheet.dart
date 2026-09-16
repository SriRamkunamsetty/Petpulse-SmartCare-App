import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/alert_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/connectivity_banner.dart';
import '../../widgets/pp_card.dart';
import '../../widgets/pp_sheet.dart';

Future<void> openAlertsSheet(BuildContext context) async {
  final app = context.read<AppState>();
  await app.openAlerts();
  if (!context.mounted) return;
  await showPpSheet(context, builder: (_) => const _AlertsSheetContent());
  app.closeSheet();
}

class _AlertsSheetContent extends StatelessWidget {
  const _AlertsSheetContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alerts', style: ppHeading(size: 20)),
            const SizedBox(height: 14),
            if (app.alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No alerts yet',
                      style: ppBody(
                          size: 13,
                          color: Colors.black.withValues(alpha: 0.5))),
                ),
              )
            else
              Column(
                children: [
                  for (final alert in app.alerts) _AlertRow(alert: alert)
                ],
              ),
          ],
        );
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});
  final AlertItem alert;

  @override
  Widget build(BuildContext context) {
    final dotColor = alert.severity == AlertSeverity.warning
        ? PpColors.accent
        : PpColors.accent2_500;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PpCard(
        elevation: PpCardElevation.sm,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: PpDot(color: dotColor)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title,
                      style: ppBody(size: 13, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(alert.detail,
                      style: ppBody(
                          size: 12,
                          color: Colors.black.withValues(alpha: 0.75))),
                  const SizedBox(height: 3),
                  Text(_relativeTime(alert.timestamp),
                      style: ppBody(
                          size: 11,
                          color: Colors.black.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat.MMMd().format(t);
  }
}
