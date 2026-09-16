/// One feeding time slot on one day of the week.
class ScheduleEntry {
  final String id;
  final String day; // 'Mon'..'Sun'
  final String time; // display string, e.g. "8:00 AM"
  final int grams;
  final bool enabled;

  const ScheduleEntry({
    required this.id,
    required this.day,
    required this.time,
    required this.grams,
    required this.enabled,
  });

  ScheduleEntry copyWith({bool? enabled, String? time, int? grams}) {
    return ScheduleEntry(
      id: id,
      day: day,
      time: time ?? this.time,
      grams: grams ?? this.grams,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'time': time,
        'grams': grams,
        'enabled': enabled,
      };

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
        id: json['id'] as String,
        day: json['day'] as String,
        time: json['time'] as String,
        grams: (json['grams'] as num).toInt(),
        enabled: json['enabled'] as bool? ?? true,
      );
}

const kWeekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
