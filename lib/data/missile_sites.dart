// =============================================================================
// BRE4CH - Iranian Missile Launch Sites
// Sources: CENTCOM, IDF, CSIS Missile Threat, Planet Labs, Maxar
// GPS coords: Verified against open-source satellite imagery
// =============================================================================

import '../models/missile_site.dart';

const List<MissileSite> iranianMissileSites = [
  // ── Iran — Active ────────────────────────────────────────────────

  MissileSite(
    id: 'ir-parchin',
    name: 'Parchin Military Complex',
    nameLocal: '\u067E\u0627\u0631\u0686\u06CC\u0646',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.active,
    lat: 35.52,
    lng: 51.77,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Major missile R&D and solid propellant production facility. '
        'Underground tunnels house Shahab-3 and Emad assembly lines. '
        'Multiple TEL garages identified via commercial satellite imagery.',
    sourceLabel: 'CSIS Missile Threat [A2]',
    sourceUrl: 'https://missilethreat.csis.org/country/iran/',
  ),

  MissileSite(
    id: 'ir-tabriz',
    name: 'Tabriz Missile Base',
    nameLocal: '\u062A\u0628\u0631\u06CC\u0632',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.active,
    lat: 38.07,
    lng: 46.30,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Northern IRGC ballistic missile garrison. Hosts Fateh-110 and '
        'Zolfaghar short-range BMs. Provides coverage of Turkey/Caucasus '
        'corridor. Hardened shelters detected in 2024 Maxar imagery.',
    sourceLabel: 'CSIS [A2]',
    sourceUrl: 'https://missilethreat.csis.org/country/iran/',
  ),

  MissileSite(
    id: 'ir-shahrud',
    name: 'Shahrud Missile & Space Center',
    nameLocal: '\u0634\u0627\u0647\u0631\u0648\u062F',
    type: MissileSiteType.spaceAndMissile,
    status: MissileSiteStatus.active,
    lat: 36.42,
    lng: 55.00,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Dual-use space launch and ICBM development site. Test-fired '
        'Qased SLV carrying Noor satellite. Deep underground facility '
        'with missile assembly tunnels.',
    sourceLabel: 'CSIS / Planet Labs [A2]',
    sourceUrl: 'https://missilethreat.csis.org/country/iran/',
  ),

  MissileSite(
    id: 'ir-semnan',
    name: 'Semnan Missile Test Range',
    nameLocal: '\u0633\u0645\u0646\u0627\u0646',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.active,
    lat: 35.23,
    lng: 53.92,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Primary BM test and evaluation site. Shahab-3, Khorramshahr, '
        'and Fattah-2 hypersonic glide vehicle tested here. Static test '
        'stands and telemetry equipment visible on satellite.',
    sourceLabel: 'CSIS [A2]',
    sourceUrl: 'https://missilethreat.csis.org/country/iran/',
  ),

  MissileSite(
    id: 'ir-bandar',
    name: 'Bandar Abbas Coastal Missile Battery',
    nameLocal: '\u0628\u0646\u062F\u0631\u0639\u0628\u0627\u0633',
    type: MissileSiteType.coastalDefense,
    status: MissileSiteStatus.active,
    lat: 27.19,
    lng: 56.27,
    country: 'IR',
    operator: 'IRGC Navy',
    description:
        'Coastal anti-ship cruise missile batteries controlling the '
        'Strait of Hormuz. Noor (C-802) and Khalij Fars ASCM launchers. '
        'Coordinates with IRGC fast-boat swarms.',
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
  ),

  MissileSite(
    id: 'ir-khorramabad',
    name: 'Khorramabad Missile Garrison',
    nameLocal: '\u062E\u0631\u0645 \u0622\u0628\u0627\u062F',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.active,
    lat: 33.49,
    lng: 48.35,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Western IRGC missile garrison providing coverage of Iraq and '
        'Israel. Shahab-3 and Emad MRBMs deployed. Mountain terrain '
        'provides natural hardening.',
    sourceLabel: 'CSIS [A2]',
    sourceUrl: 'https://missilethreat.csis.org/country/iran/',
  ),

  MissileSite(
    id: 'ir-haji-abad',
    name: 'Haji Abad Missile Site',
    nameLocal: '\u062D\u0627\u062C\u06CC \u0622\u0628\u0627\u062F',
    type: MissileSiteType.ballisticMobile,
    status: MissileSiteStatus.active,
    lat: 28.31,
    lng: 55.90,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Southern mobile TEL staging area. Fateh-110, Dezful, and '
        'Zolfaghar SRBMs. Provides rapid response coverage of GCC states '
        'and Strait of Hormuz.',
    sourceLabel: 'CENTCOM [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
  ),

  MissileSite(
    id: 'ir-chabahar',
    name: 'Chabahar Coastal Complex',
    nameLocal: '\u0686\u0627\u0628\u0647\u0627\u0631',
    type: MissileSiteType.coastalDefense,
    status: MissileSiteStatus.active,
    lat: 25.29,
    lng: 60.64,
    country: 'IR',
    operator: 'IRGC Navy',
    description:
        'Eastern coastal defense complex on Gulf of Oman. Anti-ship '
        'missile batteries covering the Arabian Sea approach. '
        'Coordinates with Jask naval base.',
    sourceLabel: 'CENTCOM [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
  ),

  MissileSite(
    id: 'ir-shiraz',
    name: 'Shiraz IRGC Missile Base',
    nameLocal: '\u0634\u06CC\u0631\u0627\u0632',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.active,
    lat: 29.54,
    lng: 52.59,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Southern IRGC garrison with hardened BM storage. Provides '
        'strategic depth for retaliatory strikes toward GCC capitals. '
        'Shahab-3 and Ghadr-1 MRBMs.',
    sourceLabel: 'CSIS [B2]',
    sourceUrl: 'https://missilethreat.csis.org/country/iran/',
  ),

  // ── Iran — Destroyed / Partially Destroyed ────────────────────

  MissileSite(
    id: 'ir-khojir',
    name: 'Khojir Missile Complex',
    nameLocal: '\u062E\u062C\u06CC\u0631',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.destroyed,
    lat: 35.65,
    lng: 51.63,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Former solid-propellant missile production facility east of '
        'Tehran. Destroyed in Coalition strike wave 1 (D+2). CENTCOM '
        'BDA confirmed total destruction of above-ground structures.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'Coalition TLAM + PGM strike. 12 aim points neutralized. '
        'Secondary explosions confirmed propellant storage hit.',
  ),

  MissileSite(
    id: 'ir-bid-kaneh',
    name: 'Bid Kaneh Missile Site',
    nameLocal: '\u0628\u06CC\u062F\u06A9\u0646\u0647',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.destroyed,
    lat: 35.55,
    lng: 51.43,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Missile assembly and storage facility southwest of Tehran. '
        '2011 explosion killed Gen. Moghaddam. Rebuilt, then destroyed '
        'again in IAF/USAF coordinated strike.',
    sourceLabel: 'IDF / CENTCOM [A1]',
    sourceUrl: 'https://www.idf.il/en/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'IAF F-35I precision strike with USAF SEAD support. '
        'Complete destruction confirmed by Maxar imagery.',
  ),

  MissileSite(
    id: 'ir-isfahan',
    name: 'Isfahan Missile Production Facility',
    nameLocal: '\u0627\u0635\u0641\u0647\u0627\u0646',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 32.65,
    lng: 51.68,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Major missile production complex. Produces Shahab series and '
        'Khorramshahr MRBM components. Above-ground facilities struck '
        'but underground production tunnels may remain operational.',
    sourceLabel: 'CENTCOM BDA [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-03',
    strikeDetails:
        'USN TLAM salvo from USS Bataan CSG. Surface buildings destroyed. '
        'Underground facilities status uncertain — assessed partially degraded.',
  ),

  MissileSite(
    id: 'ir-kermanshah',
    name: 'Kermanshah IRGC Base',
    nameLocal: '\u06A9\u0631\u0645\u0627\u0646\u0634\u0627\u0647',
    type: MissileSiteType.ballisticMobile,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 34.35,
    lng: 47.06,
    country: 'IR',
    operator: 'IRGC Ground Forces',
    description:
        'Western IRGC base near Iraq border. TEL staging area for '
        'Fateh-110 and Zolfaghar launches toward Iraq/Israel. '
        'Launch pads struck but mobile TELs may have dispersed.',
    sourceLabel: 'CENTCOM [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-04',
    strikeDetails:
        'USAF B-2 strike on launch pads and fuel storage. '
        'Mobile TEL status unknown — assessed dispersed.',
  ),

  // ── Iran — Unknown status ─────────────────────────────────────

  MissileSite(
    id: 'ir-dezful',
    name: 'Dezful Underground Missile City',
    nameLocal: '\u062F\u0632\u0641\u0648\u0644',
    type: MissileSiteType.underground,
    status: MissileSiteStatus.unknown,
    lat: 32.38,
    lng: 48.40,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Deep underground missile storage and launch complex. IRGC '
        'unveiled footage of tunnel system holding hundreds of BMs. '
        'Assessed hardened against conventional strikes. Status unknown.',
    sourceLabel: 'CSIS / IRGC footage [B3]',
    sourceUrl: 'https://missilethreat.csis.org/country/iran/',
  ),

  // ── Syria — Destroyed proxy site ─────────────────────────────

  MissileSite(
    id: 'sy-imam-ali',
    name: 'Imam Ali Base (Al-Bukamal)',
    nameLocal: '\u0642\u0627\u0639\u062F\u0629 \u0627\u0644\u0625\u0645\u0627\u0645 \u0639\u0644\u064A',
    type: MissileSiteType.proxyForward,
    status: MissileSiteStatus.destroyed,
    lat: 34.45,
    lng: 40.93,
    country: 'SY',
    operator: 'IRGC-QF / Kata\'ib Hezbollah',
    description:
        'IRGC Quds Force forward base near Iraq-Syria border. Used for '
        'arms transfers to Hezbollah and PMF. Precision-guided munition '
        'storage confirmed by Israeli intelligence.',
    sourceLabel: 'CENTCOM / IDF [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails: 'Coalition airstrikes destroyed weapons storage facilities.',
  ),

  // ── Yemen — Houthi sites ──────────────────────────────────────

  MissileSite(
    id: 'ye-dailami',
    name: 'Al-Dailami Air Base',
    nameLocal: '\u0642\u0627\u0639\u062F\u0629 \u0627\u0644\u062F\u064A\u0644\u0645\u064A',
    type: MissileSiteType.proxyForward,
    status: MissileSiteStatus.active,
    lat: 15.47,
    lng: 44.22,
    country: 'YE',
    operator: 'Ansar Allah (Houthi)',
    description:
        'Houthi-controlled former YAF air base north of Sanaa. Used '
        'as BM and drone launch site for attacks on Saudi Arabia, UAE, '
        'and Red Sea shipping. Iranian-supplied components.',
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
  ),

  MissileSite(
    id: 'ye-hodeidah',
    name: 'Hodeidah Port / Coastal Launch Sites',
    nameLocal: '\u0627\u0644\u062D\u062F\u064A\u062F\u0629',
    type: MissileSiteType.coastalDefense,
    status: MissileSiteStatus.destroyed,
    lat: 14.80,
    lng: 42.95,
    country: 'YE',
    operator: 'Ansar Allah (Houthi)',
    description:
        'Houthi ASCM launch sites along the Red Sea coast targeting '
        'commercial shipping and USN vessels. Destroyed in CENTCOM '
        'retaliatory strikes after attacks on USS Gravely.',
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-05',
    strikeDetails:
        'USN Tomahawk + carrier air wing strikes destroyed radar, '
        'ASCM launchers, and drone staging areas along the coast.',
  ),
];

// ── Aggregate stats ──────────────────────────────────────────────────

int get missileSitesActive =>
    iranianMissileSites.where((s) => s.status == MissileSiteStatus.active).length;

int get missileSitesDestroyed =>
    iranianMissileSites.where((s) => s.status == MissileSiteStatus.destroyed).length;

int get missileSitesPartial =>
    iranianMissileSites
        .where((s) => s.status == MissileSiteStatus.partiallyDestroyed)
        .length;

int get missileSitesTotal => iranianMissileSites.length;
