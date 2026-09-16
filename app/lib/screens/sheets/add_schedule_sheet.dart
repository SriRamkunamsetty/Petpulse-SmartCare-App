import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/schedule_entry.dart' show kWeekDays;
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/time_format.dart';
import '../../widgets/pp_button.dart';
import '../../widgets/pp_sheet.dart';

Future<void> openAddScheduleSheet(BuildContext context) async {
  final app = context.read<AppState>();
  app.openAddSchedule();
  await showPpSheet(context, builder: (_) => const _AddScheduleContent());
  app.closeSheet();
}

class _AddScheduleContent extends StatefulWidget {
  const _AddScheduleContent();

  @override
  State<_AddScheduleContent> createState() => _AddScheduleContentState();
}

class _AddScheduleContentState extends State<_AddScheduleContent> {
  Future<void> _pickTime(AppState app) async {
    final initial = parseTimeOfDay(app.addTime) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      app.setAddTime(formatTimeOfDay(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add feeding time', style: ppHeading(size: 20)),
            const SizedBox(height: 16),
            Text('Time',
                style: ppBody(
                    size: 12, color: PpColors.text.withValues(alpha: 0.7))),
            const SizedBox(height: 5),
            Material(
              color: PpColors.surface,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _pickTime(app),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: PpColors.divider),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(app.addTime, style: ppBody(size: 14)),
                      const Icon(Icons.access_time_rounded,
                          size: 18, color: PpColors.accent),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: PpColors.surface,
                  borderRadius: BorderRadius.circular(32)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Portion size',
                      style: ppBody(size: 13, weight: FontWeight.w600)),
                  PpStepper(
                      value: '${app.addPortion}g',
                      onInc: app.incAddPortion,
                      onDec: app.decAddPortion),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Repeat on',
                style: ppBody(
                    size: 12, color: Colors.black.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final day in kWeekDays)
                  _DayChip(
                    label: day,
                    selected: app.addDays.contains(day),
                    onTap: () => app.toggleAddDay(day),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            PpButton(
              label: 'Save',
              onPressed: app.addDays.isEmpty
                  ? null
                  : () async {
                      await app.saveSchedule();
                      if (context.mounted) Navigator.of(context).pop();
                    },
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel',
                    style: ppBody(size: 14, color: PpColors.accent)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PpColors.accent2_500 : PpColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Text(label,
              style: ppBody(
                  size: 12, color: selected ? Colors.white : PpColors.text)),
        ),
      ),
    );
  }
}
