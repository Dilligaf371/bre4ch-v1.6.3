// ── OSINT Item Model ─────────────────────────────────────────────

enum OsintSource {
  // International wire services
  reuters, aljazeera, dod, idf, ap, centcom, flightradar, bloomberg,
  // GCC newspapers — UAE
  khaleejtimes, thenational, gulfnews, gulftoday, emirates247,
  // GCC newspapers — Saudi
  arabnews, saudigazette,
  // GCC newspapers — Qatar
  gulftimes, peninsulaQatar, qatarTribune,
  // GCC newspapers — Bahrain
  gulfDailyNews, dailyTribuneBh,
  // GCC newspapers — Oman
  timesOfOman, omanObserver,
  // GCC official news agencies
  wam, spa, qna, bna, kuna, omanNews,
  // Israel
  timesOfIsrael, jpost,
}

enum OsintPriority { flash, immediate, priority, routine }

class OsintSourceConfig {
  final String label;
  final int colorValue;

  const OsintSourceConfig({required this.label, required this.colorValue});
}

class OsintItem {
  final String id;
  final OsintSource source;
  final String title;
  final String summary;
  final int timestamp;
  final OsintPriority priority;
  final String region;
  final String? url;

  const OsintItem({
    required this.id,
    required this.source,
    required this.title,
    required this.summary,
    required this.timestamp,
    required this.priority,
    required this.region,
    this.url,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.index,
    'title': title,
    'summary': summary,
    'timestamp': timestamp,
    'priority': priority.index,
    'region': region,
    'url': url,
  };

  factory OsintItem.fromJson(Map<String, dynamic> json) {
    return OsintItem(
      id: json['id'] as String? ?? '',
      source: OsintSource.values[json['source'] as int? ?? 0],
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? 0,
      priority: OsintPriority.values[json['priority'] as int? ?? 3],
      region: json['region'] as String? ?? 'Middle East',
      url: json['url'] as String?,
    );
  }

  OsintItem copyWith({
    String? id,
    OsintSource? source,
    String? title,
    String? summary,
    int? timestamp,
    OsintPriority? priority,
    String? region,
    String? url,
  }) {
    return OsintItem(
      id: id ?? this.id,
      source: source ?? this.source,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      timestamp: timestamp ?? this.timestamp,
      priority: priority ?? this.priority,
      region: region ?? this.region,
      url: url ?? this.url,
    );
  }
}
