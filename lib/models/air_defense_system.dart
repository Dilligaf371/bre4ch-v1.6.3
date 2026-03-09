// =============================================================================
// BRE4CH - Air Defense System Model
// GCC / Coalition air defense systems with interception statistics
// =============================================================================

enum DefenseSystemType {
  thaad,
  patriotPac3,
  patriotPac2,
  patriotPac3Mse,
  arrowSystem,
  davidsSling,
  ironDome,
  ironBeam,
  nasams,
  hawk,
  hq9,
  aegis,
  cheongungII,
  barakER,
}

extension DefenseSystemLabel on DefenseSystemType {
  String get label {
    switch (this) {
      case DefenseSystemType.thaad:
        return 'THAAD';
      case DefenseSystemType.patriotPac3:
        return 'PATRIOT PAC-3';
      case DefenseSystemType.patriotPac2:
        return 'PATRIOT PAC-2';
      case DefenseSystemType.arrowSystem:
        return 'ARROW 2/3';
      case DefenseSystemType.davidsSling:
        return "DAVID'S SLING";
      case DefenseSystemType.ironDome:
        return 'IRON DOME';
      case DefenseSystemType.ironBeam:
        return 'IRON BEAM';
      case DefenseSystemType.nasams:
        return 'NASAMS';
      case DefenseSystemType.hawk:
        return 'I-HAWK';
      case DefenseSystemType.hq9:
        return 'HQ-9';
      case DefenseSystemType.aegis:
        return 'AEGIS (SM-3/SM-6)';
      case DefenseSystemType.cheongungII:
        return 'CHEONGUNG-II (M-SAM)';
      case DefenseSystemType.barakER:
        return 'BARAK ER';
      case DefenseSystemType.patriotPac3Mse:
        return 'PATRIOT PAC-3 MSE';
    }
  }
}

class InterceptionStats {
  final int ballisticIntercepted;
  final int cruiseIntercepted;
  final int droneIntercepted;
  final int totalIntercepted;
  final String lastUpdated;

  const InterceptionStats({
    required this.ballisticIntercepted,
    required this.cruiseIntercepted,
    required this.droneIntercepted,
    required this.totalIntercepted,
    required this.lastUpdated,
  });

  factory InterceptionStats.fromJson(Map<String, dynamic> json) {
    final ballistic = json['ballisticIntercepted'] as int? ?? 0;
    final cruise = json['cruiseIntercepted'] as int? ?? 0;
    final drone = json['droneIntercepted'] as int? ?? 0;
    return InterceptionStats(
      ballisticIntercepted: ballistic,
      cruiseIntercepted: cruise,
      droneIntercepted: drone,
      totalIntercepted: json['totalIntercepted'] as int? ?? (ballistic + cruise + drone),
      lastUpdated: json['lastUpdated'] as String? ?? '',
    );
  }
}

class AirDefenseSystem {
  final String id;
  final String name;
  final String country;         // 'UAE', 'KSA', 'Israel', etc.
  final String countryFlag;     // emoji flag
  final List<DefenseSystemType> systems;
  final double lat;
  final double lng;
  final String description;
  final InterceptionStats stats;
  final String sourceLabel;     // e.g. '@modgovae (X) — 7 Mar 2026'
  final String sourceUrl;
  final DateTime sourceDate;    // Publication date+time (UTC) of the source
  final String? baseName;       // Military base name
  final String operator;        // 'UAE Armed Forces', 'US CENTCOM', 'IDF', etc.

  const AirDefenseSystem({
    required this.id,
    required this.name,
    required this.country,
    required this.countryFlag,
    required this.systems,
    required this.lat,
    required this.lng,
    required this.description,
    required this.stats,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.sourceDate,
    this.baseName,
    required this.operator,
  });

  /// Human-readable "time ago" from [sourceDate].
  String get sourceAgo {
    final diff = DateTime.now().toUtc().difference(sourceDate);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Formatted source timestamp: "7 MAR 2026 · 14:22 UTC"
  String get sourceTimestamp {
    const months = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final h = sourceDate.hour.toString().padLeft(2, '0');
    final m = sourceDate.minute.toString().padLeft(2, '0');
    return '${sourceDate.day} ${months[sourceDate.month]} ${sourceDate.year} · $h:$m UTC';
  }

  /// Returns a copy with updated fields (for dynamic API/overlay data).
  AirDefenseSystem copyWith({
    InterceptionStats? stats,
    String? description,
    String? sourceLabel,
    String? sourceUrl,
    DateTime? sourceDate,
  }) {
    return AirDefenseSystem(
      id: id,
      name: name,
      country: country,
      countryFlag: countryFlag,
      systems: systems,
      lat: lat,
      lng: lng,
      description: description ?? this.description,
      stats: stats ?? this.stats,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceDate: sourceDate ?? this.sourceDate,
      baseName: baseName,
      operator: operator,
    );
  }
}
