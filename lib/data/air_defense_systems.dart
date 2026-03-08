// =============================================================================
// BRE4CH - GCC / Coalition Air Defense Systems
// Sources: MOD UAE, MOD Kuwait, BDF Bahrain, MOD Qatar, MOD KSA, IDF, CENTCOM
// Interception stats: Cumulative since mission start (28 FEB 2026 02:00 UTC)
// =============================================================================

import '../models/air_defense_system.dart';

/// Mission start date for daily average computation
final DateTime missionStart = DateTime.utc(2026, 2, 28, 2, 0, 0);

const List<AirDefenseSystem> coalitionAirDefense = [
  // ── UAE ────────────────────────────────────────────────────────────

  AirDefenseSystem(
    id: 'ad-uae-dhafra',
    name: 'Al Dhafra AB — Integrated Air Defense',
    country: 'UAE',
    countryFlag: '\u{1F1E6}\u{1F1EA}',
    systems: [DefenseSystemType.thaad, DefenseSystemType.patriotPac3],
    lat: 24.25,
    lng: 54.55,
    description:
        'Primary IAMD hub for UAE defense. US THAAD battery and '
        'Patriot PAC-3 co-located with UAE Air Force. Highest '
        'interception rate in theater. Defends Abu Dhabi critical infrastructure.',
    stats: InterceptionStats(
      ballisticIntercepted: 165,
      cruiseIntercepted: 0,
      droneIntercepted: 541,
      totalIntercepted: 706,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'MOD UAE / CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    baseName: 'Al Dhafra Air Base',
    operator: 'UAE Armed Forces / US CENTCOM',
  ),

  // ── Kuwait ─────────────────────────────────────────────────────────

  AirDefenseSystem(
    id: 'ad-kw-arifjan',
    name: 'Camp Arifjan — Kuwait Air Defense Zone',
    country: 'Kuwait',
    countryFlag: '\u{1F1F0}\u{1F1FC}',
    systems: [DefenseSystemType.patriotPac3, DefenseSystemType.patriotPac2, DefenseSystemType.hawk],
    lat: 29.07,
    lng: 48.08,
    description:
        'Multi-layered air defense covering Kuwait City and '
        'US military installations. Patriot batteries at Camp Arifjan '
        'and Ali Al Salem AB provide overlapping coverage.',
    stats: InterceptionStats(
      ballisticIntercepted: 97,
      cruiseIntercepted: 0,
      droneIntercepted: 283,
      totalIntercepted: 380,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'MOD Kuwait [A2]',
    sourceUrl: 'https://www.mofa.gov.kw/',
    baseName: 'Camp Arifjan / Ali Al Salem AB',
    operator: 'Kuwait Armed Forces / US Army',
  ),

  // ── Bahrain ────────────────────────────────────────────────────────

  AirDefenseSystem(
    id: 'ad-bh-nsa',
    name: 'NSA Bahrain — 5th Fleet Air Defense',
    country: 'Bahrain',
    countryFlag: '\u{1F1E7}\u{1F1ED}',
    systems: [DefenseSystemType.patriotPac3],
    lat: 26.24,
    lng: 50.62,
    description:
        'US 5th Fleet HQ defense. Patriot batteries protect Manama, '
        'Isa AB, and naval facilities. Bahrain Defense Force augments '
        'with SHORAD systems.',
    stats: InterceptionStats(
      ballisticIntercepted: 45,
      cruiseIntercepted: 0,
      droneIntercepted: 9,
      totalIntercepted: 54,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'BDF / NAVCENT [A2]',
    sourceUrl: 'https://www.bdf.bh/',
    baseName: 'NSA Bahrain / Isa AB',
    operator: 'BDF / US NAVCENT',
  ),

  // ── Qatar ──────────────────────────────────────────────────────────

  AirDefenseSystem(
    id: 'ad-qa-udeid',
    name: 'Al Udeid AB — CAOC Air Defense',
    country: 'Qatar',
    countryFlag: '\u{1F1F6}\u{1F1E6}',
    systems: [DefenseSystemType.patriotPac3, DefenseSystemType.nasams],
    lat: 25.12,
    lng: 51.32,
    description:
        'Largest US base in Middle East. Houses Combined Air Operations '
        'Center (CAOC). Patriot + NASAMS provide layered defense. '
        'Critical C2 node for entire theater.',
    stats: InterceptionStats(
      ballisticIntercepted: 12,
      cruiseIntercepted: 3,
      droneIntercepted: 3,
      totalIntercepted: 18,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'MOD Qatar / CENTCOM [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    baseName: 'Al Udeid Air Base',
    operator: 'Qatar Emiri AF / US CENTCOM',
  ),

  // ── Saudi Arabia ───────────────────────────────────────────────────

  AirDefenseSystem(
    id: 'ad-ksa-riyadh',
    name: 'Riyadh IAMD — Royal Saudi Air Defense',
    country: 'KSA',
    countryFlag: '\u{1F1F8}\u{1F1E6}',
    systems: [DefenseSystemType.patriotPac3, DefenseSystemType.hq9, DefenseSystemType.ironDome],
    lat: 24.71,
    lng: 46.68,
    description:
        'Multi-vendor air defense network protecting Riyadh, Aramco '
        'facilities, and eastern province infrastructure. Patriot PAC-3, '
        'Chinese HQ-9, and recently deployed Iron Dome batteries.',
    stats: InterceptionStats(
      ballisticIntercepted: 89,
      cruiseIntercepted: 12,
      droneIntercepted: 156,
      totalIntercepted: 257,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'MOD KSA / SPA [A2]',
    sourceUrl: 'https://www.spa.gov.sa/',
    baseName: 'Prince Sultan AB / King Abdulaziz AB',
    operator: 'Royal Saudi Air Defense Forces',
  ),

  // ── Oman ───────────────────────────────────────────────────────────

  AirDefenseSystem(
    id: 'ad-om-muscat',
    name: 'Muscat — Royal Air Force of Oman',
    country: 'Oman',
    countryFlag: '\u{1F1F4}\u{1F1F2}',
    systems: [DefenseSystemType.patriotPac2],
    lat: 23.59,
    lng: 58.28,
    description:
        'Limited air defense coverage. Duqm Port was attacked early '
        'in the conflict. RAFO maintains basic Patriot PAC-2 coverage '
        'around Muscat and Musandam peninsula.',
    stats: InterceptionStats(
      ballisticIntercepted: 3,
      cruiseIntercepted: 1,
      droneIntercepted: 7,
      totalIntercepted: 11,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'MOD Oman [B2]',
    sourceUrl: 'https://www.mod.gov.om/',
    baseName: 'Muscat AFB',
    operator: 'Royal Air Force of Oman',
  ),

  // ── Israel ─────────────────────────────────────────────────────────

  AirDefenseSystem(
    id: 'ad-il-center',
    name: 'Israel Multi-Tier IAMD',
    country: 'Israel',
    countryFlag: '\u{1F1EE}\u{1F1F1}',
    systems: [
      DefenseSystemType.arrowSystem,
      DefenseSystemType.davidsSling,
      DefenseSystemType.ironDome,
      DefenseSystemType.ironBeam,
    ],
    lat: 31.90,
    lng: 34.81,
    description:
        'World\'s most advanced multi-layered air defense. Arrow 3 '
        '(exo-atmospheric), Arrow 2 (endo-atmospheric), David\'s Sling '
        '(MRBM/cruise), Iron Dome (rockets/mortars), Iron Beam (laser). '
        '99%+ intercept rate against Iranian BM salvos.',
    stats: InterceptionStats(
      ballisticIntercepted: 412,
      cruiseIntercepted: 87,
      droneIntercepted: 1034,
      totalIntercepted: 1533,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'IDF Spokesperson [A1]',
    sourceUrl: 'https://www.idf.il/en/',
    baseName: 'Palmachim AB / Nevatim AB',
    operator: 'Israel Defense Forces — Air Defense Command',
  ),

  // ── US CENTCOM Naval ───────────────────────────────────────────────

  AirDefenseSystem(
    id: 'ad-us-aegis',
    name: 'CENTCOM Aegis BMD — Arabian Sea',
    country: 'US',
    countryFlag: '\u{1F1FA}\u{1F1F8}',
    systems: [DefenseSystemType.aegis, DefenseSystemType.thaad],
    lat: 25.50,
    lng: 57.00,
    description:
        'US Navy Aegis BMD-equipped cruisers and destroyers (USS Bataan '
        'CSG, USS Gravely). SM-3 Block IIA for exo-atmospheric intercept, '
        'SM-6 for terminal defense. THAAD battery at Al Dhafra supplements.',
    stats: InterceptionStats(
      ballisticIntercepted: 78,
      cruiseIntercepted: 34,
      droneIntercepted: 0,
      totalIntercepted: 112,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    baseName: 'CSG Arabian Sea',
    operator: 'US CENTCOM / NAVCENT',
  ),
];

// ── Aggregate stats ──────────────────────────────────────────────────

int get totalInterceptionsAllCoalition =>
    coalitionAirDefense.fold(0, (sum, ad) => sum + ad.stats.totalIntercepted);

int get totalBallisticInterceptions =>
    coalitionAirDefense.fold(0, (sum, ad) => sum + ad.stats.ballisticIntercepted);

int get totalDroneInterceptions =>
    coalitionAirDefense.fold(0, (sum, ad) => sum + ad.stats.droneIntercepted);
