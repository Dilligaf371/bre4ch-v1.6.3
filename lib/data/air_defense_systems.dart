// =============================================================================
// BRE4CH - GCC / Coalition Air Defense Systems
// Sources: @modgovae (X), WAM, MOD Kuwait, BDF/Gulf News, QNA, @modgovksa,
//          SPA, Arab News, MOD Oman, IDF Spokesperson, CENTCOM
// Interception stats: Cumulative since mission start (28 FEB 2026 02:00 UTC)
// Last verified: 2026-03-08
// =============================================================================

import '../models/air_defense_system.dart';

/// Mission start date for daily average computation
final DateTime missionStart = DateTime.utc(2026, 2, 28, 2, 0, 0);

const List<AirDefenseSystem> coalitionAirDefense = [
  // ── UAE ────────────────────────────────────────────────────────────
  // Source: @modgovae on X / WAM / Korea Times / Army Recognition
  // UAE owns 2 THAAD batteries (Abu Dhabi + Al-Ruwais), US deploys
  // 2 additional Patriot PAC-3 batteries. Cheongung-II achieved 96%
  // hit rate in first-ever combat use. Barak ER deployed post-Abraham Accords.
  // AN/TPY-2 radar at Al Dhafra was struck/destroyed by Iranian BMs D+5.
  // Stats (MOD UAE infographic 07-03-2026):
  //   BM:     221 detected → 205 intercepted / 14 impacts at sea / 2 impacts on land
  //   CM:       8 detected →   8 intercepted (100%)
  //   UAVs: 1305 detected → 1229 intercepted / 76 impacts on land

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
        'BM: 221 detected → 205 intercepted (14 sea / 2 land impacts).\n'
        'CM: 8 detected → 8 intercepted (100%).\n'
        'UAVs: 1305 detected → 1229 intercepted (76 land impacts).\n'
        'Source: MOD UAE official infographic, 7 March 2026.',
    stats: InterceptionStats(
      ballisticIntercepted: 205,
      cruiseIntercepted: 8,
      droneIntercepted: 1229,
      totalIntercepted: 1442,
      lastUpdated: '2026-03-07',
    ),
    sourceLabel: '@modgovae (X) — 7 Mar 2026',
    sourceUrl: 'https://x.com/modgovae/status/2030241691115126947',
    baseName: 'Al Dhafra Air Base',
    operator: 'UAE Armed Forces / US CENTCOM',
  ),

  // ── Kuwait ─────────────────────────────────────────────────────────
  // Source: Kuwait MOD, Times Kuwait, Anadolu Agency
  // 97 Iranian BMs + 283 drones intercepted

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
        '97 Iranian ballistic missiles and 283 drones destroyed.',
    stats: InterceptionStats(
      ballisticIntercepted: 97,
      cruiseIntercepted: 0,
      droneIntercepted: 283,
      totalIntercepted: 380,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'Times Kuwait / Anadolu — Mar 2026',
    sourceUrl: 'https://timeskuwait.com/kuwait-army-air-defenses-intercept-missile-and-drone-attacks-in-airspace/',
    baseName: 'Camp Arifjan / Ali Al Salem AB',
    operator: 'Kuwait Armed Forces / US Army',
  ),

  // ── Bahrain ────────────────────────────────────────────────────────
  // Source: BDF General Command, Gulf News
  // 75 missiles + 123 drones = 198 total

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
        'with SHORAD systems. BDF General Command reported 75 missiles '
        'and 123 drones intercepted.',
    stats: InterceptionStats(
      ballisticIntercepted: 75,
      cruiseIntercepted: 0,
      droneIntercepted: 123,
      totalIntercepted: 198,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'BDF / Gulf News — Mar 2026',
    sourceUrl: 'https://gulfnews.com/amp/story/world/mena/bahrain-defence-force-intercepted-75-missiles-and-123-drones-since-start-of-attacks-1.500464224',
    baseName: 'NSA Bahrain / Isa AB',
    operator: 'BDF / US NAVCENT',
  ),

  // ── Qatar ──────────────────────────────────────────────────────────
  // Source: QNA, Anadolu Agency, Middle East Monitor
  // 101 BM detected → 98 intercepted / 3 CM intercepted / 39 drones
  // 2 Iranian Su-24 aircraft shot down

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
        '39 drones neutralized. 2 Iranian Su-24 aircraft shot down.',
    stats: InterceptionStats(
      ballisticIntercepted: 98,
      cruiseIntercepted: 3,
      droneIntercepted: 39,
      totalIntercepted: 140,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'QNA — 4 Mar 2026',
    sourceUrl: 'https://qna.org.qa/en/news/news-details?id=defense-ministry-announces-successful-interception-of-10-drones-and-two-cruise-missiles&date=4/03/2026',
    baseName: 'Al Udeid Air Base',
    operator: 'Qatar Emiri AF / US CENTCOM',
  ),

  // ── Saudi Arabia ───────────────────────────────────────────────────
  // Source: @modgovksa on X, SPA, Arab News
  // KSA less targeted — first THAAD battery operational July 2025.
  // March 7: 3 BM + 2 CM intercepted over Al-Kharj, 5 drones neutralized.
  // Shaybah oilfield: 6 drones intercepted.
  // $9B PAC-3 MSE replenishment sale approved Feb 2026 (DSCA).

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
        '\$15B contract). KSA less directly targeted than Gulf littoral states.',
    stats: InterceptionStats(
      ballisticIntercepted: 5,
      cruiseIntercepted: 2,
      droneIntercepted: 11,
      totalIntercepted: 18,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'Arab News / SPA — 7 Mar 2026',
    sourceUrl: 'https://www.arabnews.com/node/2635432/saudi-arabia',
    baseName: 'Prince Sultan AB / King Abdulaziz AB',
    operator: 'Royal Saudi Air Defense Forces',
  ),

  // ── Oman ───────────────────────────────────────────────────────────
  // Source: MOD Oman, Argus Media, Iran International
  // Very limited disclosure. 2 drones intercepted over Dhofar Province.
  // Duqm port struck by drones — fuel tank damaged, 1 worker injured.

  AirDefenseSystem(
    id: 'ad-om-muscat',
    name: 'Muscat — Royal Air Force of Oman',
    country: 'Oman',
    countryFlag: '\u{1F1F4}\u{1F1F2}',
    systems: [DefenseSystemType.patriotPac2],
    lat: 23.59,
    lng: 58.28,
    description:
        'Limited air defense coverage. Duqm Port was struck early '
        'in the conflict — fuel tank damaged, 1 worker injured. '
        'RAFO maintains basic Patriot PAC-2 coverage around Muscat '
        'and Musandam. 2 drones intercepted over Dhofar Province. '
        'Very limited official disclosure.',
    stats: InterceptionStats(
      ballisticIntercepted: 0,
      cruiseIntercepted: 0,
      droneIntercepted: 2,
      totalIntercepted: 2,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'Iran Intl / Anadolu — 3 Mar 2026',
    sourceUrl: 'https://www.iranintl.com/en/202603031726',
    baseName: 'Muscat AFB',
    operator: 'Royal Air Force of Oman',
  ),

  // ── Israel ─────────────────────────────────────────────────────────
  // Source: IDF Spokesperson, FDD analysis
  // Ref: April 2024 — 320 projectiles, 99% intercepted (IDF)
  //      Oct 2024 — ~200 BMs, ~90% intercepted
  //      March 2026 — Iran allocated ~40% of firepower toward Israel
  // FDD: 86% success rate in missile interception during conflict
  // Arrow 3: exo-atmospheric (combat debut Oct 2023 vs Houthi BM)
  // Iron Dome: 5,000+ cumulative interceptions since 2011 (Rafael)

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
        'FDD assessed 86% overall interception rate during conflict.',
    stats: InterceptionStats(
      ballisticIntercepted: 312,
      cruiseIntercepted: 87,
      droneIntercepted: 876,
      totalIntercepted: 1275,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'FDD / IDF Spokesperson — Mar 2026',
    sourceUrl: 'https://www.fdd.org/analysis/2026/03/04/israel-conducts-1600-strikes-on-iran-in-4-days-of-war-weathers-iranian-missile-and-drones/',
    baseName: 'Palmachim AB / Nevatim AB',
    operator: 'Israel Defense Forces — Air Defense Command',
  ),

  // ── US CENTCOM Naval ───────────────────────────────────────────────
  // Source: CENTCOM, Stars & Stripes, USNI News, The War Zone
  // Red Sea campaign: 380 threats defeated, 220 missiles fired (15 months)
  // SM-3 first combat use: April 14, 2024 vs Iranian BMs (4-7 SM-3 fired)
  // USS Carney: 51 engagements, 65 Houthi targets destroyed
  // USS Gravely: Phalanx CIWS vs cruise missile at 1 NM
  // Eisenhower CSG: 770 munitions expended (~$1.16B)

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
        'SM-6 terminal, SM-2 area defense). First SM-3 combat use April 2024 '
        'vs Iranian BMs. 15-month Red Sea campaign: 380 threats defeated, '
        '220 missiles and 160 gun rounds expended. THAAD battery supplements.',
    stats: InterceptionStats(
      ballisticIntercepted: 42,
      cruiseIntercepted: 18,
      droneIntercepted: 0,
      totalIntercepted: 60,
      lastUpdated: '2026-03-08',
    ),
    sourceLabel: 'CENTCOM / USNI News — 28 Feb 2026',
    sourceUrl: 'https://news.usni.org/2026/02/28/u-s-israel-launch-operation-epic-fury-against-iran-tehran-retaliates-across-region',
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
