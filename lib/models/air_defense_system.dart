// =============================================================================
// BRE4CH - Air Defense System Model
// GCC / Coalition air defense systems with interception statistics
// =============================================================================

enum DefenseSystemType {
  thaad,
  patriotPac3,
  patriotPac2,
  arrowSystem,
  davidsSling,
  ironDome,
  ironBeam,
  nasams,
  hawk,
  hq9,
  aegis,
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
  final String sourceLabel;     // e.g. 'MOD UAE [A2]'
  final String sourceUrl;
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
    this.baseName,
    required this.operator,
  });

  /// Returns a copy with updated [InterceptionStats] (for dynamic API data).
  AirDefenseSystem copyWith({InterceptionStats? stats}) {
    return AirDefenseSystem(
      id: id,
      name: name,
      country: country,
      countryFlag: countryFlag,
      systems: systems,
      lat: lat,
      lng: lng,
      description: description,
      stats: stats ?? this.stats,
      sourceLabel: sourceLabel,
      sourceUrl: sourceUrl,
      baseName: baseName,
      operator: operator,
    );
  }
}
