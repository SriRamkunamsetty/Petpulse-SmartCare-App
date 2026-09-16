import 'package:flutter/material.dart';

/// The prototype's schedule times are plain strings like "7:00 AM" —
/// these two helpers are the single place that format/parse that exact
/// shape, used by the time picker (add_schedule_sheet.dart) and the
/// next-feeding computation (state/app_state.dart).
String formatTimeOfDay(TimeOfDay t) {
  final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// Returns minutes since midnight, or null if [s] isn't in "h:mm AM/PM"
/// shape.
int? parseTimeToMinutes(String s) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
      .firstMatch(s.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final period = match.group(3)!.toUpperCase();
  if (hour == 12) hour = 0;
  if (period == 'PM') hour += 12;
  return hour * 60 + minute;
}

TimeOfDay? parseTimeOfDay(String s) {
  final minutes = parseTimeToMinutes(s);
  if (minutes == null) return null;
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}
