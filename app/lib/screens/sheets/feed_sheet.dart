import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/pp_button.dart';
import '../../widgets/pp_sheet.dart';

Future<void> openFeedSheet(BuildContext context) async {
  final app = context.read<AppState>();
  app.openFeedSheet();
  await showPpSheet(context, builder: (_) => const _FeedSheetContent());
  app.closeSheet();
}

class _FeedSheetContent extends StatelessWidget {
  const _FeedSheetContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        return switch (app.feedStage) {
          FeedStage.confirm => _Confirm(app: app),
          FeedStage.feeding => _Feeding(app: app),
          FeedStage.done => _Done(app: app),
        };
      },
    );
  }
}

class _Confirm extends StatelessWidget {
  const _Confirm({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feed ${app.pet.name.isEmpty ? "your pet" : app.pet.name} now?',
            style: ppHeading(size: 20)),
        const SizedBox(height: 4),
        Text(
          'Dispenses a manual portion right away, outside the schedule.',
          style: ppBody(size: 13, color: Colors.black.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
              color: PpColors.surface, borderRadius: BorderRadius.circular(32)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Portion size',
                  style: ppBody(size: 13, weight: FontWeight.w600)),
              PpStepper(
                  value: '${app.manualPortion}g',
                  onInc: app.incPortion,
                  onDec: app.decPortion),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PpButton(
            label: 'Dispense ${app.manualPortion}g',
            onPressed: app.startFeeding),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Cancel', style: ppBody(size: 14, color: PpColors.accent)),
          ),
        ),
      ],
    );
  }
}

class _Feeding extends StatelessWidget {
  const _Feeding({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final pct =
        app.manualPortion == 0 ? 0.0 : app.feedCurrentGrams / app.manualPortion;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text('Feeding ${app.pet.name.isEmpty ? "your pet" : app.pet.name}…',
              style: ppHeading(size: 20)),
          const SizedBox(height: 18),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: pct.clamp(0, 1),
                    strokeWidth: 8,
                    backgroundColor: PpColors.neutral300,
                    valueColor: const AlwaysStoppedAnimation(PpColors.accent),
                  ),
                ),
                Text('${app.feedCurrentGrams}g', style: ppHeading(size: 22)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Target ${app.manualPortion}g · Servo active',
            style: ppBody(size: 13, color: Colors.black.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _Done extends StatefulWidget {
  const _Done({required this.app});
  final AppState app;

  @override
  State<_Done> createState() => _DoneState();
}

class _DoneState extends State<_Done> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  AppState get app => widget.app;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: PpColors.accent2_100, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: PpColors.accent2_700, size: 28),
            ),
          ),
          const SizedBox(height: 14),
          Text('Feeding complete', style: ppHeading(size: 20)),
          const SizedBox(height: 4),
          Text(
            'Dispensed ${app.manualPortion}g just now.',
            style: ppBody(size: 13, color: Colors.black.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 18),
          PpButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
