import 'connectivity_state.dart';

/// Snapshot returned by `GET /api/v1/telemetry` — polled on an interval by
/// [PollingService]. See docs/API_CONTRACT.md.
class Telemetry {
  final double bowlWeightGrams;
  final int foodLevelPct;

  /// Raw distance the ultrasonic sensor measures down to the bowl/food
  /// surface, in cm — a different reading than [foodLevelPct] (which is
  /// the hopper-fill percentage). Null on servers that don't report it.
  final double? bowlHeightCm;
  final String nextFeedTime;
  final int nextFeedGrams;
  final PpConnectivity connectivity;
  final DateTime lastUpdated;
  final String lastRefilled;

  const Telemetry({
    required this.bowlWeightGrams,
    required this.foodLevelPct,
    this.bowlHeightCm,
    required this.nextFeedTime,
    required this.nextFeedGrams,
    required this.connectivity,
    required this.lastUpdated,
    this.lastRefilled = '',
  });

  static Telemetry placeholder() => Telemetry(
        bowlWeightGrams: 0,
        foodLevelPct: 0,
        nextFeedTime: '--:--',
        nextFeedGrams: 0,
        connectivity: PpConnectivity.cloudUnreachable,
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
      );

  factory Telemetry.fromJson(Map<String, dynamic> json) => Telemetry(
        bowlWeightGrams: (json['bowl_weight_grams'] as num).toDouble(),
        foodLevelPct: (json['food_level_pct'] as num).toInt(),
        bowlHeightCm: (json['bowl_height_cm'] as num?)?.toDouble(),
        nextFeedTime: json['next_feed_time'] as String? ?? '--:--',
        nextFeedGrams: (json['next_feed_grams'] as num?)?.toInt() ?? 0,
        connectivity: PpConnectivity.fromWire(
            json['connectivity'] as String? ?? 'online'),
        lastUpdated: DateTime.parse(json['last_updated'] as String),
        lastRefilled: json['last_refilled'] as String? ?? '',
      );
}
