import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/pp_button.dart';
import '../widgets/pp_card.dart';
import 'sheets/add_schedule_sheet.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entries = app.scheduleForSelectedDay;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule', style: ppHeading(size: 30)),
                      const SizedBox(height: 2),
                      Text('Time & day-based feeding',
                          style: ppBody(
                              size: 13,
                              color: PpColors.text.withValues(alpha: 0.55))),
                    ],
                  ),
                ),
                PpGlassButton(
                  onTap: () => openAddScheduleSheet(context),
                  child: const Icon(Icons.add_rounded,
                      size: 18, color: Color(0xFF3A3632)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: kWeekDays.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final day = kWeekDays[i];
                final selected = day == app.selectedDay;
                return Material(
                  color: selected ? PpColors.accent : Colors.transparent,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    side: BorderSide(color: PpColors.divider),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => app.selectDay(day),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      child: Text(day,
                          style: ppBody(
                              size: 13,
                              color: selected ? Colors.white : PpColors.text)),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              children: [
                for (final entry in entries) ...[
                  _ScheduleRow(
                      entry: entry,
                      onToggle: () => app.toggleScheduleItem(entry)),
                  const SizedBox(height: 10),
                ],
                PpButton(
                  label: '+ Add feeding time',
                  variant: PpButtonVariant.secondary,
                  height: 46,
                  onPressed: () => openAddScheduleSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.entry, required this.onToggle});
  final ScheduleEntry entry;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return PpCard(
      elevation: PpCardElevation.sm,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
                color: PpColors.accent100, shape: BoxShape.circle),
            child: const Icon(Icons.schedule_rounded,
                color: PpColors.accent700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.time, style: ppHeading(size: 16)),
                PpCardMeta('${entry.grams}g portion'),
              ],
            ),
          ),
          PpSwitch(value: entry.enabled, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}
