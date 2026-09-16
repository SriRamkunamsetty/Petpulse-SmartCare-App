enum AlertSeverity { warning, info }

class AlertItem {
  final String id;
  final String title;
  final String detail;
  final DateTime timestamp;
  final AlertSeverity severity;
  final bool read;

  const AlertItem({
    required this.id,
    required this.title,
    required this.detail,
    required this.timestamp,
    required this.severity,
    this.read = false,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
        id: json['id'] as String,
        title: json['title'] as String,
        detail: json['detail'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        severity: AlertSeverity.values.firstWhere(
          (s) => s.name == json['severity'],
          orElse: () => AlertSeverity.info,
        ),
        read: json['read'] as bool? ?? false,
      );
}
