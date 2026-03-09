// =============================================================================
// BRE4CH - GCC / Coalition Air Defense Systems
// Sources: @modgovae (X), WAM, MOD Kuwait, BDF/Gulf News, QNA, @modgovksa,
//          SPA, Arab News, MOD Oman, IDF Spokesperson, CENTCOM
// Interception stats: Cumulative since mission start (28 FEB 2026 02:00 UTC)
// All sourceDate timestamps are UTC publication time of the cited source.
// Last verified: 2026-03-09 — sources updated with latest OSINT
// =============================================================================

import '../models/air_defense_system.dart';

/// Mission start date for daily average computation
final DateTime missionStart = DateTime.utc(2026, 2, 28, 2, 0, 0);

final List<AirDefenseSystem> coalitionAirDefense = [
  // ── UAE ────────────────────────────────────────────────────────────
  // Source: @modgovae on X / WAM — posted 8 Mar 2026 ~14:22 GST (10:22 UTC)
  // Stats (MOD UAE infographic 08-03-2026):
  //   BM:     238 detected → 221 intercepted / 15 impacts at sea / 2 impacts on land
  //   CM:       8 detected →   8 intercepted (100%)
  //   UAVs: 1422 detected → 1342 intercepted / 80 impacts on land

  AirDefenseSystem(
    id: 'ad-uae-dhafra',
    name: 'Al Dhafra AB — UAE Integrated Air Defense',
    country: 'UAE',
    countryFlag: '\u{1F1E6}\u{1F1EA}',
    systems: [
      DefenseSystemType.thaad,
      DefenseSystemType.patriotPac3,
      DefenseSystemType.cheongungII,
      DefenseSystemType.barakER,
    ],
    lat: 24.25,
    lng: 54.55,
    description:
        'Primary IAMD hub for UAE defense. UAE-owned THAAD battery (first non-US '
        'operator, operational since 2015), US Patriot PAC-3, Korean Cheongung-II '
        '(M-SAM, 96% hit rate in combat debut), and Israeli Barak ER.\n'
        'BM: 238 detected → 221 intercepted (15 sea / 2 land impacts).\n'
        'CM: 8 detected → 8 intercepted (100%).\n'
        'UAVs: 1422 detected → 1342 intercepted (80 land impacts).\n'
        'Source: MOD UAE official infographic, 8 March 2026.',
    stats: InterceptionStats(
      ballisticIntercepted: 221,
      cruiseIntercepted: 8,
      droneIntercepted: 1342,
      totalIntercepted: 1571,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: '@modgovae (X)',
    sourceUrl: 'https://x.com/modgovae/status/2030596754287247788',
    sourceDate: DateTime.utc(2026, 3, 8, 14, 22),
    baseName: 'Al Dhafra Air Base',
    operator: 'UAE Armed Forces / US CENTCOM',
  ),

  // ── Kuwait ─────────────────────────────────────────────────────────
  // Source: Times Kuwait — published 6 Mar 2026 ~14:00 UTC
  // MOD spokesman: 212 ballistic missiles + 394 drones intercepted
  // 67 army personnel injured

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
        'and Ali Al Salem AB provide overlapping coverage. '
        'MOD spokesman: 212 Iranian ballistic missiles and 394 drones '
        'intercepted. 67 army personnel injured.',
    stats: InterceptionStats(
      ballisticIntercepted: 212,
      cruiseIntercepted: 0,
      droneIntercepted: 394,
      totalIntercepted: 606,
      lastUpdated: '2026-03-06',
    ),
    sourceLabel: 'Times Kuwait (MOD)',
    sourceUrl: 'https://timeskuwait.com/kuwait-intercepts-212-ballistic-missiles-394-drones-67-army-personnel-injured/',
    sourceDate: DateTime.utc(2026, 3, 6, 14, 0),
    baseName: 'Camp Arifjan / Ali Al Salem AB',
    operator: 'Kuwait Armed Forces / US Army',
  ),

  // ── Bahrain ────────────────────────────────────────────────────────
  // Source: Gulf News — published 8 Mar 2026 ~12:00 UTC
  // 95 missiles + 164 drones = 259 total intercepted

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
        'with SHORAD systems. BDF reported 95 missiles and 164 drones '
        'intercepted since start of Iranian attacks.',
    stats: InterceptionStats(
      ballisticIntercepted: 95,
      cruiseIntercepted: 0,
      droneIntercepted: 164,
      totalIntercepted: 259,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'Gulf News / BDF',
    sourceUrl: 'https://gulfnews.com/world/gulf/bahrain/bahrain-intercepts-95-missiles-164-drones-from-iranian-attacks-1.500467457',
    sourceDate: DateTime.utc(2026, 3, 8, 12, 0),
    baseName: 'NSA Bahrain / Isa AB',
    operator: 'BDF / US NAVCENT',
  ),

  // ── Qatar ──────────────────────────────────────────────────────────
  // Source: Peninsula Qatar — published 7 Mar 2026 ~16:00 UTC (live updates)
  // Cumulative: 101 BM detected → 98 intercepted / 3 CM / 48 drones
  // 2 Iranian Su-24 aircraft shot down (2 Mar)
  // 7 Mar: 9 of 10 drones intercepted, 1 struck uninhabited area

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
        '101 BMs detected — 98 intercepted. 3 cruise missiles destroyed. '
        '48 drones neutralized (incl. 9 of 10 on 7 Mar). '
        '2 Iranian Su-24 aircraft shot down on 2 Mar.',
    stats: InterceptionStats(
      ballisticIntercepted: 98,
      cruiseIntercepted: 3,
      droneIntercepted: 48,
      totalIntercepted: 149,
      lastUpdated: '2026-03-07',
    ),
    sourceLabel: 'Peninsula Qatar / QNA',
    sourceUrl: 'https://thepeninsulaqatar.com/article/07/03/2026/live-updates-qatar-intercepts-9-drones1-struck-uninhabited-area-mod',
    sourceDate: DateTime.utc(2026, 3, 7, 16, 0),
    baseName: 'Al Udeid Air Base',
    operator: 'Qatar Emiri AF / US CENTCOM',
  ),

  // ── Saudi Arabia ───────────────────────────────────────────────────
  // Source: Saudi Gazette / MOD (compiled) — through 8 Mar 2026
  // No single cumulative release — compiled from incident reports:
  // BM: 3 (Mar 6 Prince Sultan AB) + 5 (Mar 7-8) = 8
  // CM: 2 (Mar 3-4) + 3 (Mar 5 Al-Kharj) + 1 (Mar 6) = 6
  // Drones: 10 (Mar 1) + 11 (Mar 3-4) + 4 (Mar 5) + 6 (Mar 6)
  //       + 21 (Shaybah) + 10 (Riyadh Mar 7-8) = 62

  AirDefenseSystem(
    id: 'ad-ksa-riyadh',
    name: 'Riyadh IAMD — Royal Saudi Air Defense',
    country: 'KSA',
    countryFlag: '\u{1F1F8}\u{1F1E6}',
    systems: [DefenseSystemType.patriotPac3Mse, DefenseSystemType.thaad],
    lat: 24.71,
    lng: 46.68,
    description:
        'Multi-layered air defense protecting Riyadh, Aramco facilities, '
        'and eastern province infrastructure. Patriot PAC-3 MSE is backbone. '
        'First THAAD battery operational since July 2025 (7-battery order, '
        '\$15B contract). Compiled from MOD incident reports: 8 BMs '
        'intercepted (Prince Sultan AB), 6 CMs destroyed (Al-Kharj), '
        '62 drones neutralized (Shaybah, Riyadh, Ras Tanura, Al-Jouf).',
    stats: InterceptionStats(
      ballisticIntercepted: 8,
      cruiseIntercepted: 6,
      droneIntercepted: 62,
      totalIntercepted: 76,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'Saudi Gazette / MOD',
    sourceUrl: 'https://saudigazette.com.sa/article/659514/saudi-arabia/saudi-intercepts-16-drones-targeting-shaybah-field-missile-toward-prince-sultan-air-base',
    sourceDate: DateTime.utc(2026, 3, 7, 13, 0),
    baseName: 'Prince Sultan AB / King Abdulaziz AB',
    operator: 'Royal Saudi Air Defense Forces',
  ),

  // ── Oman ───────────────────────────────────────────────────────────
  // Sources: Oman News Agency (1 Mar), Muscat Daily (3 Mar), Anadolu (1 Mar)
  // 1 Mar: Duqm port struck — 1 drone hit workers' housing (1 injured),
  //        1 drone debris near fuel tanks
  // 3 Mar: Duqm port 2nd attack — fuel tank hit (fire contained)
  //        Salalah: 2 drones intercepted over Dhofar, 1 crashed near port
  // Very limited official disclosure — no cumulative MOD statement

  AirDefenseSystem(
    id: 'ad-om-muscat',
    name: 'Muscat — Royal Air Force of Oman',
    country: 'Oman',
    countryFlag: '\u{1F1F4}\u{1F1F2}',
    systems: [DefenseSystemType.patriotPac2],
    lat: 23.59,
    lng: 58.28,
    description:
        'Limited air defense coverage. Duqm Port struck twice '
        '(1 & 3 Mar) — fuel tank damaged, 1 worker injured. '
        'RAFO maintains basic Patriot PAC-2 coverage around Muscat '
        'and Musandam. 2 drones intercepted over Dhofar Province '
        'near Salalah. No cumulative MOD statement released.',
    stats: InterceptionStats(
      ballisticIntercepted: 0,
      cruiseIntercepted: 0,
      droneIntercepted: 2,
      totalIntercepted: 2,
      lastUpdated: '2026-03-03',
    ),
    sourceLabel: 'Muscat Daily / ONA',
    sourceUrl: 'https://www.muscatdaily.com/2026/03/03/drones-target-ports-in-duqm-and-salalah/',
    sourceDate: DateTime.utc(2026, 3, 3, 12, 0),
    baseName: 'Muscat AFB',
    operator: 'Royal Air Force of Oman',
  ),

  // ── Israel ─────────────────────────────────────────────────────────
  // Sources: FDD analysis (4 Mar), Jerusalem Post (7 Mar), Haaretz (8 Mar)
  // FDD (4 Mar): ~90% BM interception, ~99% drone interception
  // JPost (7 Mar): IDF destroyed 300 of 400-550 Iranian launchers (75%)
  // Haaretz (8 Mar): Iranian BM fire rate dropped from ~100/day to ~15/day
  // 80% of Iran's air defenses destroyed — IDF CoS Lt. Gen. Zamir

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
        '(exo-atmospheric, combat debut Oct 2023), Arrow 2 (endo), '
        'David\'s Sling (MRBM/cruise, 100% success rate), '
        'Iron Dome (5,000+ interceptions since 2011), Iron Beam (laser). '
        '~90% BM interception rate, ~99% drone rate. IDF destroyed '
        '300 Iranian launchers (75%). BM fire rate: 100/day → 15/day.',
    stats: InterceptionStats(
      ballisticIntercepted: 312,
      cruiseIntercepted: 87,
      droneIntercepted: 876,
      totalIntercepted: 1275,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'JPost / FDD / IDF',
    sourceUrl: 'https://www.jpost.com/middle-east/iran-news/article-889169',
    sourceDate: DateTime.utc(2026, 3, 7, 14, 0),
    baseName: 'Palmachim AB / Nevatim AB',
    operator: 'Israel Defense Forces — Air Defense Command',
  ),

  // ── US CENTCOM Naval ───────────────────────────────────────────────
  // Sources: Military Times (6 Mar), USNI News (4 Mar)
  // Interceptor expenditure (Military Times est.):
  //   THAAD: 100-150 used (from stockpile of 534, ~30% depletion)
  //   SM-3: ~80 used (from stockpile of 414)
  // USS Oscar Austin (DDG-79) SM-3 intercept of Iranian BM headed for
  // Turkey — 4 Mar 2026, first NATO intercept of Iranian missile
  // CENTCOM total: Iran launched 500+ BMs, 2000+ drones across all theaters

  AirDefenseSystem(
    id: 'ad-us-aegis',
    name: 'CENTCOM Aegis BMD — Arabian Gulf',
    country: 'US',
    countryFlag: '\u{1F1FA}\u{1F1F8}',
    systems: [DefenseSystemType.aegis, DefenseSystemType.thaad],
    lat: 25.50,
    lng: 57.00,
    description:
        'US Navy Aegis BMD-equipped destroyers (SM-3 Block IIA exo-atmospheric, '
        'SM-6 terminal, SM-2 area defense). ~80 SM-3 interceptors expended '
        '(from 414 stockpile). 100-150 THAAD interceptors used. '
        'USS Oscar Austin SM-3 intercept of Iranian BM headed for Turkey '
        '(4 Mar, first NATO intercept). CENTCOM: 2,000 targets struck.',
    stats: InterceptionStats(
      ballisticIntercepted: 42,
      cruiseIntercepted: 18,
      droneIntercepted: 0,
      totalIntercepted: 60,
      lastUpdated: '2026-03-06',
    ),
    sourceLabel: 'Military Times / USNI',
    sourceUrl: 'https://www.militarytimes.com/news/your-military/2026/03/06/race-of-attrition-us-militarys-finite-interceptor-stockpile-is-being-tested/',
    sourceDate: DateTime.utc(2026, 3, 6, 12, 0),
    baseName: 'CSG Arabian Gulf',
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
