// =============================================================================
// BRE4CH - Iranian Missile Launch Site Model
// Sites de lancement de missiles iraniens — actifs, détruits, partiellement
// =============================================================================

enum MissileSiteStatus { active, destroyed, partiallyDestroyed, unknown }

enum MissileSiteType {
  ballisticFixed,
  ballisticMobile,
  cruiseMissile,
  coastalDefense,
  spaceAndMissile,
  underground,
  proxyForward,
  leadershipCommand,
  nuclearFacility,
  airBase,
  navalBase,
  defenseIndustry,
  droneBase,
  radarSam,
}

class MissileSite {
  final String id;
  final String name;
  final String nameLocal;
  final MissileSiteType type;
  final MissileSiteStatus status;
  final double lat;
  final double lng;
  final String country;        // 'IR', 'SY', 'YE'
  final String operator;       // 'IRGC-ASF', 'Houthi', etc.
  final String description;
  final String sourceLabel;    // e.g. 'CENTCOM — 1 Mar 2026'
  final String sourceUrl;
  final DateTime sourceDate;   // Publication date+time (UTC) of the source
  final String? photoUrl;
  final String? photoCaption;
  final String? lastStrikeDate;
  final String? strikeDetails;

  const MissileSite({
    required this.id,
    required this.name,
    required this.nameLocal,
    required this.type,
    required this.status,
    required this.lat,
    required this.lng,
    required this.country,
    required this.operator,
    required this.description,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.sourceDate,
    this.photoUrl,
    this.photoCaption,
    this.lastStrikeDate,
    this.strikeDetails,
  });

  /// Human-readable "time ago" from [sourceDate].
  String get sourceAgo {
    final diff = DateTime.now().toUtc().difference(sourceDate);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Formatted source timestamp: "1 MAR 2026 · 06:15 UTC"
  String get sourceTimestamp {
    const months = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final h = sourceDate.hour.toString().padLeft(2, '0');
    final m = sourceDate.minute.toString().padLeft(2, '0');
    return '${sourceDate.day} ${months[sourceDate.month]} ${sourceDate.year} · $h:$m UTC';
  }
}

// ── Status labels ──────────────────────────────────────────────────

extension MissileSiteStatusLabel on MissileSiteStatus {
  String get label {
    switch (this) {
      case MissileSiteStatus.active:
        return 'ACTIVE';
      case MissileSiteStatus.destroyed:
        return 'DESTROYED';
      case MissileSiteStatus.partiallyDestroyed:
        return 'PARTIAL';
      case MissileSiteStatus.unknown:
        return 'UNKNOWN';
    }
  }
}

extension MissileSiteTypeLabel on MissileSiteType {
  String get label {
    switch (this) {
      case MissileSiteType.ballisticFixed:
        return 'BALLISTIC (FIXED)';
      case MissileSiteType.ballisticMobile:
        return 'BALLISTIC (TEL)';
      case MissileSiteType.cruiseMissile:
        return 'CRUISE MISSILE';
      case MissileSiteType.coastalDefense:
        return 'COASTAL DEFENSE';
      case MissileSiteType.spaceAndMissile:
        return 'SPACE / MISSILE';
      case MissileSiteType.underground:
        return 'UNDERGROUND';
      case MissileSiteType.proxyForward:
        return 'PROXY / FORWARD';
      case MissileSiteType.leadershipCommand:
        return 'LEADERSHIP / C2';
      case MissileSiteType.nuclearFacility:
        return 'NUCLEAR';
      case MissileSiteType.airBase:
        return 'AIR BASE';
      case MissileSiteType.navalBase:
        return 'NAVAL BASE';
      case MissileSiteType.defenseIndustry:
        return 'DEFENSE INDUSTRY';
      case MissileSiteType.droneBase:
        return 'DRONE / UAV';
      case MissileSiteType.radarSam:
        return 'RADAR / SAM';
    }
  }
}
