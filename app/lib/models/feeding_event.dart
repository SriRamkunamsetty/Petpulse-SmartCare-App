enum FeedingResult { completed, skipped, failed }

class FeedingEvent {
  final String id;
  final DateTime timestamp;
  final int grams;
  final FeedingResult result;
  final String note;

  const FeedingEvent({
    required this.id,
    required this.timestamp,
    required this.grams,
    required this.result,
    this.note = '',
  });

  factory FeedingEvent.fromJson(Map<String, dynamic> json) => FeedingEvent(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        grams: (json['grams'] as num).toInt(),
        result: FeedingResult.values.firstWhere(
          (r) => r.name == json['result'],
          orElse: () => FeedingResult.completed,
        ),
        note: json['note'] as String? ?? '',
      );
}

class DayIntake {
  final String label;
  final int grams;
  const DayIntake(this.label, this.grams);

  factory DayIntake.fromJson(Map<String, dynamic> json) => DayIntake(
        json['label'] as String,
        (json['grams'] as num).toInt(),
      );
}
