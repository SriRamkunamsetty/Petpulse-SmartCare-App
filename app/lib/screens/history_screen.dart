import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/feeding_event.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/pp_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final maxGrams = app.weekBars.isEmpty
        ? 1
        : app.weekBars.map((b) => b.grams).reduce((a, b) => a > b ? a : b);
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
                Text('History', style: ppHeading(size: 30)),
                const SizedBox(height: 2),
                Text("This week's feeding activity",
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
                PpCard(
                  elevation: PpCardElevation.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PpCardKicker('Grams dispensed / day'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 110,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final bar in app.weekBars)
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        height: maxGrams == 0
                                            ? 0
                                            : 84 * (bar.grams / maxGrams),
                                        constraints:
                                            const BoxConstraints(minHeight: 4),
                                        decoration: BoxDecoration(
                                          color: PpColors.accent2_400,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(bar.label,
                                          style: ppBody(
                                              size: 10,
                                              color: PpColors.text
                                                  .withValues(alpha: 0.55))),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PpCard(
                  elevation: PpCardElevation.sm,
                  color: PpColors.accent100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.warning_amber_rounded,
                            size: 18, color: PpColors.accent800),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style:
                                ppBody(size: 12.5, color: PpColors.accent800),
                            children: [
                              const TextSpan(
                                  text: 'Intake down 15%',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(
                                  text:
                                      ' vs last week — consider checking in on ${app.pet.name.isEmpty ? "your pet" : app.pet.name}.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: PpCardKicker('Recent activity'),
                ),
                if (app.historyEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('No feeding activity yet',
                        style: ppBody(
                            size: 13,
                            color: PpColors.text.withValues(alpha: 0.5))),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: PpColors.surface,
                      borderRadius: BorderRadius.circular(PpRadius.md),
                      boxShadow: PpShadow.sm,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < app.historyEvents.length; i++)
                          _EventRow(
                              event: app.historyEvents[i],
                              showDivider: i < app.historyEvents.length - 1),
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

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.showDivider});
  final FeedingEvent event;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final completed = event.result == FeedingResult.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: PpColors.divider))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 18,
            color: completed ? PpColors.accent2_700 : PpColors.neutral500,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dayLabel(event.timestamp),
                    style: ppBody(size: 13, weight: FontWeight.w700)),
                PpCardMeta(completed
                    ? 'Dispensed ${event.grams}g · Completed'
                    : (event.note.isEmpty
                        ? 'Skipped'
                        : 'Skipped · ${event.note}')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final prefix = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat.MMMd().format(t);
    return '$prefix · ${DateFormat.jm().format(t)}';
  }
}
