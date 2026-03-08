// =============================================================================
// BRE4CH - Iranian Military Strike Targets
// Comprehensive list of all US (CENTCOM) and Israeli (IDF) strike targets
// Sources: CENTCOM Press Releases, IDF Spokesperson, CSIS Missile Threat,
//          Planet Labs, Maxar Technologies, ISW
// GPS coords: Verified against open-source satellite imagery
// =============================================================================

import '../models/missile_site.dart';

const List<MissileSite> iranianMissileSites = [
  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 1 — LEADERSHIP / COMMAND & CONTROL (3 targets)
  // ═══════════════════════════════════════════════════════════════════

  MissileSite(
    id: 'ir-irgc-hq',
    name: 'IRGC Aerospace Force HQ',
    nameLocal: '\u0633\u062A\u0627\u062F \u0646\u06CC\u0631\u0648\u06CC \u0647\u0648\u0627\u0641\u0636\u0627\u06CC \u0633\u067E\u0627\u0647',
    type: MissileSiteType.leadershipCommand,
    status: MissileSiteStatus.destroyed,
    lat: 35.7000,
    lng: 51.4200,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'IRGC-ASF strategic command center in Tehran. Coordinated all '
        'ballistic missile and drone operations against Coalition targets. '
        'Destroyed in IAF/USAF precision strike D+1.',
    sourceLabel: 'CENTCOM / IDF [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'Combined IAF F-35I and USAF B-2 strike. Command bunker penetrated '
        'by GBU-57 MOP. Total destruction confirmed by ISR.',
  ),

  MissileSite(
    id: 'ir-modafl-hq',
    name: 'MODAFL Headquarters',
    nameLocal: '\u0648\u0632\u0627\u0631\u062A \u062F\u0641\u0627\u0639',
    type: MissileSiteType.leadershipCommand,
    status: MissileSiteStatus.destroyed,
    lat: 35.7150,
    lng: 51.3800,
    country: 'IR',
    operator: 'Ministry of Defense (MODAFL)',
    description:
        'Ministry of Defense and Armed Forces Logistics. Oversaw defense '
        'procurement, missile development programs, and DIO subsidiaries. '
        'Administrative complex struck D+2.',
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'USAF JDAM/JSOW strike package. Main administrative buildings '
        'destroyed. Adjacent R&D annex heavily damaged.',
  ),

  MissileSite(
    id: 'ir-irgc-joc',
    name: 'IRGC Joint Operations Center',
    nameLocal: '\u0645\u0631\u06A9\u0632 \u0639\u0645\u0644\u06CC\u0627\u062A \u0645\u0634\u062A\u0631\u06A9',
    type: MissileSiteType.leadershipCommand,
    status: MissileSiteStatus.destroyed,
    lat: 32.6300,
    lng: 51.7000,
    country: 'IR',
    operator: 'IRGC',
    description:
        'Redundant joint operations center near Isfahan. Backup C2 node '
        'for missile and air defense coordination. Identified via SIGINT '
        'after Tehran HQ destruction.',
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-04',
    strikeDetails:
        'USN TLAM salvo from USS Bataan CSG. Deep bunker assessed '
        'destroyed based on post-strike SIGINT silence.',
  ),

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 2 — BALLISTIC MISSILE BASES (15 targets)
  // ═══════════════════════════════════════════════════════════════════

  // ── Active (not struck or reconstituted) ───────────────────────

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
    id: 'ir-tabriz-missile',
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
    id: 'ir-shiraz-missile',
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

  // ── Destroyed ──────────────────────────────────────────────────

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
    name: 'Bid Kaneh / Shahid Bagheri Industries',
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
    id: 'ir-razan',
    name: 'Razan / Shahid Mohajer Missile Base',
    nameLocal: '\u0631\u0632\u0646',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.destroyed,
    lat: 35.25,
    lng: 49.03,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'MRBM garrison west of Tehran. Shahab-3 and Emad TEL staging area. '
        'Used in Oct 2024 salvo against Israel. Struck in initial wave.',
    sourceLabel: 'IDF / CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'IAF long-range strike with USAF aerial refueling support. '
        'All TEL shelters and launch pads destroyed.',
  ),

  MissileSite(
    id: 'ir-tab-e-sabz',
    name: 'Tab-e Sabz Missile Garrison',
    nameLocal: '\u062A\u0628 \u0633\u0628\u0632',
    type: MissileSiteType.ballisticFixed,
    status: MissileSiteStatus.destroyed,
    lat: 35.40,
    lng: 51.50,
    country: 'IR',
    operator: 'IRGC Aerospace Force',
    description:
        'Missile garrison in Greater Tehran area. Hardened shelters for '
        'Fateh-110 and Dezful SRBMs. Destroyed during first wave of '
        'Coalition strikes targeting Tehran-area missile infrastructure.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USAF B-2 Spirit strike with JDAM GPS-guided munitions. '
        '8 hardened shelters neutralized.',
  ),

  // ── Partially Destroyed ────────────────────────────────────────

  MissileSite(
    id: 'ir-isfahan-missile',
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

  MissileSite(
    id: 'ir-ahvaz',
    name: 'Ahvaz IRGC Missile Site',
    nameLocal: '\u0627\u0647\u0648\u0627\u0632',
    type: MissileSiteType.ballisticMobile,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 31.32,
    lng: 48.67,
    country: 'IR',
    operator: 'IRGC Ground Forces',
    description:
        'Khuzestan IRGC mobile missile staging area. Fateh-class SRBM '
        'launchers targeting Kuwait and Basra. Fuel depot struck but '
        'mobile TELs assessed dispersed into urban areas.',
    sourceLabel: 'CENTCOM [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-05',
    strikeDetails:
        'USN carrier air wing strike from USS Eisenhower. Fuel storage '
        'and maintenance buildings destroyed. TELs status uncertain.',
  ),

  // ── Unknown status ─────────────────────────────────────────────

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

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 3 — NUCLEAR FACILITIES (4 targets)
  // ═══════════════════════════════════════════════════════════════════

  MissileSite(
    id: 'ir-natanz',
    name: 'Natanz Fuel Enrichment Plant (FEP)',
    nameLocal: '\u0646\u0637\u0646\u0632',
    type: MissileSiteType.nuclearFacility,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 33.7250,
    lng: 51.7270,
    country: 'IR',
    operator: 'AEOI (Atomic Energy Org.)',
    description:
        'Primary uranium enrichment facility. Underground centrifuge halls '
        'buried 8m below surface under concrete. Above-ground assembly '
        'halls destroyed. Underground centrifuge cascade status uncertain.',
    sourceLabel: 'CENTCOM / IAEA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'USAF B-2 strike with GBU-57 MOP bunker busters. Surface facilities '
        'destroyed. Underground halls assessed partially degraded — '
        'post-strike IAEA monitoring disrupted.',
  ),

  MissileSite(
    id: 'ir-fordow',
    name: 'Fordow Fuel Enrichment Plant (FFEP)',
    nameLocal: '\u0641\u0631\u062F\u0648',
    type: MissileSiteType.nuclearFacility,
    status: MissileSiteStatus.unknown,
    lat: 34.8830,
    lng: 51.9840,
    country: 'IR',
    operator: 'AEOI',
    description:
        'Deeply buried enrichment facility inside a mountain near Qom. '
        'Assessed hardened against conventional munitions including GBU-57 MOP. '
        'Multiple B-2 sorties attempted — BDA inconclusive.',
    sourceLabel: 'CENTCOM / IAEA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-03',
    strikeDetails:
        'Multiple B-2 sorties with GBU-57 MOP. Tunnel entrances collapsed. '
        'Internal status unknown — facility buried 80m+ inside mountain.',
  ),

  MissileSite(
    id: 'ir-isfahan-ucf',
    name: 'Isfahan Nuclear Technology Center (UCF)',
    nameLocal: '\u0645\u0631\u06A9\u0632 \u0641\u0646\u0627\u0648\u0631\u06CC \u0647\u0633\u062A\u0647\u200C\u0627\u06CC',
    type: MissileSiteType.nuclearFacility,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 32.6400,
    lng: 51.6500,
    country: 'IR',
    operator: 'AEOI',
    description:
        'Uranium Conversion Facility (UCF) converting yellowcake to UF6. '
        'Also hosts Fuel Manufacturing Plant and Zirconium Production Plant. '
        'Chemical processing buildings destroyed.',
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-03',
    strikeDetails:
        'USN TLAM salvo. Chemical processing lines destroyed. '
        'Contamination risk prevented ground assessment.',
  ),

  MissileSite(
    id: 'ir-arak',
    name: 'Arak IR-40 Heavy Water Reactor',
    nameLocal: '\u0631\u0627\u06A9\u062A\u0648\u0631 \u0622\u0628 \u0633\u0646\u06AF\u06CC\u0646 \u0627\u0631\u0627\u06A9',
    type: MissileSiteType.nuclearFacility,
    status: MissileSiteStatus.destroyed,
    lat: 34.3790,
    lng: 49.2430,
    country: 'IR',
    operator: 'AEOI',
    description:
        'Heavy water reactor capable of plutonium production. '
        'Modified under JCPOA but restored to original design post-2023. '
        'Reactor building and cooling towers destroyed.',
    sourceLabel: 'CENTCOM / IAEA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'IAF/USAF coordinated strike. Reactor vessel penetrated. '
        'Heavy water production plant destroyed. Environmental '
        'monitoring ongoing.',
  ),

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 4 — AIR BASES / AIRFIELDS (7 targets)
  // ═══════════════════════════════════════════════════════════════════

  MissileSite(
    id: 'ir-isfahan-afb',
    name: 'Isfahan / Khatami Air Base (TFB.8)',
    nameLocal: '\u067E\u0627\u06CC\u06AF\u0627\u0647 \u0634\u0647\u06CC\u062F \u062E\u0627\u062A\u0645\u06CC',
    type: MissileSiteType.airBase,
    status: MissileSiteStatus.destroyed,
    lat: 32.7500,
    lng: 51.8600,
    country: 'IR',
    operator: 'IRIAF',
    description:
        'Major IRIAF fighter base housing F-14A Tomcats and Su-24 Fencers. '
        'Primary air defense interceptor base for central Iran. '
        'Runway, HAS, and ATC tower destroyed.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USAF F-22 + F-15E SEAD/DEAD followed by TLAM salvos. All '
        'hardened aircraft shelters (HAS) destroyed. Runway cratered '
        'at 6 points. 4 F-14A destroyed on ground.',
  ),

  MissileSite(
    id: 'ir-tabriz-afb',
    name: 'Tabriz Air Base (TFB.2)',
    nameLocal: '\u067E\u0627\u06CC\u06AF\u0627\u0647 \u062A\u0628\u0631\u06CC\u0632',
    type: MissileSiteType.airBase,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 38.1330,
    lng: 46.2350,
    country: 'IR',
    operator: 'IRIAF',
    description:
        'Northern IRIAF fighter base hosting F-5E/F Tiger IIs and MiG-29s. '
        'Runway partially repaired after initial strikes. Some aircraft '
        'may have dispersed to highway strips.',
    sourceLabel: 'CENTCOM [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USAF cruise missile strike. Runway cratered, HAS struck. '
        'Partial repairs observed in subsequent imagery — '
        'follow-up strike planned.',
  ),

  MissileSite(
    id: 'ir-bushehr-afb',
    name: 'Bushehr Air Base (TFB.6)',
    nameLocal: '\u067E\u0627\u06CC\u06AF\u0627\u0647 \u0628\u0648\u0634\u0647\u0631',
    type: MissileSiteType.airBase,
    status: MissileSiteStatus.destroyed,
    lat: 28.9500,
    lng: 50.8300,
    country: 'IR',
    operator: 'IRIAF',
    description:
        'Coastal IRIAF base near Bushehr nuclear power plant. Hosted '
        'F-4E Phantoms for maritime strike missions. Runway and '
        'maintenance facilities destroyed.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USN carrier air wing strike from USS Eisenhower. 3 F-4E '
        'destroyed on ground. All support buildings neutralized.',
  ),

  MissileSite(
    id: 'ir-mehrabad',
    name: 'Mehrabad / Tehran TFB.1',
    nameLocal: '\u0645\u0647\u0631\u0622\u0628\u0627\u062F',
    type: MissileSiteType.airBase,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 35.6900,
    lng: 51.3100,
    country: 'IR',
    operator: 'IRIAF / IRGC-AF',
    description:
        'Dual-use military/civil airport west of Tehran. IRIAF transport '
        'and VIP aircraft. Military apron and IRGC hangars struck. '
        'Civilian terminal spared.',
    sourceLabel: 'CENTCOM [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'Precision JDAM strike on military-only infrastructure. '
        'IRGC-AF hangars destroyed. Civilian runway operational.',
  ),

  MissileSite(
    id: 'ir-hamadan-afb',
    name: 'Hamadan / Shahid Nojeh Air Base (TFB.3)',
    nameLocal: '\u067E\u0627\u06CC\u06AF\u0627\u0647 \u0634\u0647\u06CC\u062F \u0646\u0648\u0698\u0647',
    type: MissileSiteType.airBase,
    status: MissileSiteStatus.destroyed,
    lat: 34.9700,
    lng: 48.6500,
    country: 'IR',
    operator: 'IRIAF',
    description:
        'Strategic IRIAF base that hosted Russian Tu-22M3 bombers in 2016. '
        'Su-24 Fencer attack aircraft and IRGC drone operations. '
        'Complete destruction of all military infrastructure.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USAF B-2 + F-15E combined strike. All HAS, runway, fuel storage '
        'destroyed. 2 Su-24 and 3 Shahed-136 drone launchers confirmed '
        'destroyed by Maxar BDA.',
  ),

  MissileSite(
    id: 'ir-bandar-afb',
    name: 'Bandar Abbas / Havadarya Air Base',
    nameLocal: '\u0647\u0648\u0627\u062F\u0631\u06CC\u0627',
    type: MissileSiteType.airBase,
    status: MissileSiteStatus.destroyed,
    lat: 27.1600,
    lng: 56.2300,
    country: 'IR',
    operator: 'IRIAF / IRGC-AF',
    description:
        'Major air base controlling Strait of Hormuz airspace. F-14A '
        'interceptors and IRGC-AF drone wing. Critical for maritime '
        'denial operations.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USN/USAF combined strike. Runway cratered, all HAS destroyed, '
        'radar complex neutralized. 2 F-14A confirmed destroyed.',
  ),

  MissileSite(
    id: 'ir-omidiyeh-afb',
    name: 'Omidiyeh / Vahdati Air Base (TFB.5)',
    nameLocal: '\u0627\u0645\u06CC\u062F\u06CC\u0647',
    type: MissileSiteType.airBase,
    status: MissileSiteStatus.destroyed,
    lat: 30.8400,
    lng: 49.5300,
    country: 'IR',
    operator: 'IRIAF',
    description:
        'Khuzestan IRIAF base hosting F-4E Phantoms and Su-25 Frogfoots. '
        'Closest fighter base to Kuwait and southern Iraq. '
        'Complete destruction confirmed.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USN TLAM salvo from Arabian Gulf destroyers. All aircraft shelters, '
        'ammunition storage, and fuel farm destroyed.',
  ),

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 5 — NAVAL BASES (4 targets)
  // ═══════════════════════════════════════════════════════════════════

  MissileSite(
    id: 'ir-bandar-naval',
    name: 'Bandar Abbas IRIN Naval Base',
    nameLocal: '\u0628\u0646\u062F\u0631\u0639\u0628\u0627\u0633 \u0646\u06CC\u0631\u0648\u06CC \u062F\u0631\u06CC\u0627\u06CC\u06CC',
    type: MissileSiteType.navalBase,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 27.1500,
    lng: 56.3000,
    country: 'IR',
    operator: 'IRIN (Islamic Republic of Iran Navy)',
    description:
        'Largest Iranian naval base. Home port for frigates, corvettes, '
        'and Kilo-class submarines. IRGCN fast attack craft pens located '
        'adjacent. Port facilities partially damaged.',
    sourceLabel: 'CENTCOM / NAVCENT [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'USN Harpoon and TLAM strikes. IRGCN fast-boat pens destroyed. '
        'IRIN pier facilities damaged. 1 Mowj-class frigate confirmed sunk, '
        '3 Kilo submarines assessed in port during strike.',
  ),

  MissileSite(
    id: 'ir-bushehr-naval',
    name: 'Bushehr / IRGCN Naval District 2',
    nameLocal: '\u0646\u0627\u062D\u06CC\u0647 \u062F\u0631\u06CC\u0627\u06CC\u06CC \u0628\u0648\u0634\u0647\u0631',
    type: MissileSiteType.navalBase,
    status: MissileSiteStatus.destroyed,
    lat: 28.9600,
    lng: 50.8200,
    country: 'IR',
    operator: 'IRGC Navy',
    description:
        'IRGCN fast attack craft base and coastal missile battery. '
        'C-802/Noor ASCM launchers and armed speedboats. '
        'Complete destruction of naval pens and missile storage.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USN carrier air wing + TLAM. All ASCM launchers destroyed. '
        '12 fast attack craft confirmed sunk/destroyed in pens.',
  ),

  MissileSite(
    id: 'ir-jask-naval',
    name: 'Jask Naval Forward Operating Base',
    nameLocal: '\u062C\u0627\u0633\u06A9',
    type: MissileSiteType.navalBase,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 25.6400,
    lng: 57.7700,
    country: 'IR',
    operator: 'IRIN / IRGCN',
    description:
        'New naval FOB on Gulf of Oman coast. Forward staging for ASCM '
        'operations beyond the Strait. Mine warfare and submarine '
        'support facilities.',
    sourceLabel: 'CENTCOM [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-03',
    strikeDetails:
        'USN TLAM strike. Pier and maintenance facilities damaged. '
        'ASCM storage bunker destroyed. Some infrastructure intact.',
  ),

  MissileSite(
    id: 'ir-asaluyeh-naval',
    name: 'Asaluyeh IRGCN Naval Station',
    nameLocal: '\u0639\u0633\u0644\u0648\u06CC\u0647',
    type: MissileSiteType.navalBase,
    status: MissileSiteStatus.destroyed,
    lat: 27.4800,
    lng: 52.6100,
    country: 'IR',
    operator: 'IRGC Navy',
    description:
        'IRGCN station adjacent to South Pars gas complex. Fast attack '
        'craft and mining operations. Located near critical energy '
        'infrastructure — precision strikes only on military targets.',
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'Precision JSOW + SDB strike from USAF F-15E. Naval pens and '
        'ASCM storage destroyed. South Pars gas facilities undamaged.',
  ),

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 6 — COASTAL DEFENSE / ASCM (2 targets)
  // ═══════════════════════════════════════════════════════════════════

  MissileSite(
    id: 'ir-bandar-ascm',
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
        'Coordinates with IRGC fast-boat swarms. Mobile launchers redeployed.',
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
  ),

  MissileSite(
    id: 'ir-chabahar-coastal',
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

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 7 — DEFENSE INDUSTRY (4 targets)
  // ═══════════════════════════════════════════════════════════════════

  MissileSite(
    id: 'ir-lavizan',
    name: 'DIO / Lavizan Technology Complex',
    nameLocal: '\u0644\u0648\u06CC\u0632\u0627\u0646',
    type: MissileSiteType.defenseIndustry,
    status: MissileSiteStatus.destroyed,
    lat: 35.7800,
    lng: 51.5000,
    country: 'IR',
    operator: 'DIO (Defense Industries Org.)',
    description:
        'Defense Industries Organization R&D campus. Weapons systems '
        'development, guidance system research, and warhead design. '
        'Previously linked to undeclared nuclear research.',
    sourceLabel: 'CENTCOM / IAEA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'USAF JDAM strike. R&D buildings and test laboratories destroyed. '
        'Classified materials assessed destroyed in post-strike fire.',
  ),

  MissileSite(
    id: 'ir-shiraz-iei',
    name: 'Iran Electronics Industries (IEI) Shiraz',
    nameLocal: '\u0635\u0646\u0627\u06CC\u0639 \u0627\u0644\u06A9\u062A\u0631\u0648\u0646\u06CC\u06A9 \u0627\u06CC\u0631\u0627\u0646',
    type: MissileSiteType.defenseIndustry,
    status: MissileSiteStatus.destroyed,
    lat: 29.6100,
    lng: 52.5300,
    country: 'IR',
    operator: 'DIO / MODAFL',
    description:
        'Primary manufacturer of military electronics, radar systems, '
        'missile guidance computers, and C4ISR equipment. Produces '
        'components for Bavar-373 and S-300 radar integration.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-03',
    strikeDetails:
        'USN TLAM + USAF SDB strike. Production lines destroyed. '
        'Assembly halls collapsed. Critical node for IADS reconstitution.',
  ),

  MissileSite(
    id: 'ir-hemmat',
    name: 'Shahid Hemmat Industrial Group (SHIG)',
    nameLocal: '\u06AF\u0631\u0648\u0647 \u0635\u0646\u0639\u062A\u06CC \u0634\u0647\u06CC\u062F \u0647\u0645\u062A',
    type: MissileSiteType.defenseIndustry,
    status: MissileSiteStatus.destroyed,
    lat: 35.5800,
    lng: 51.4000,
    country: 'IR',
    operator: 'IRGC-ASF / MODAFL',
    description:
        'Primary liquid-fueled ballistic missile developer. Responsible for '
        'Shahab-3, Ghadr-1, Emad, and Khorramshahr programs. '
        'Fabrication and final assembly facility.',
    sourceLabel: 'CENTCOM / CSIS [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-02',
    strikeDetails:
        'IAF/USAF coordinated strike. All assembly buildings destroyed. '
        'Liquid propellant tanks detonated — large secondary explosions.',
  ),

  MissileSite(
    id: 'ir-sanam',
    name: 'SANAM Industries Complex, Isfahan',
    nameLocal: '\u0635\u0646\u0627\u06CC\u0639 \u0635\u0646\u0627\u0645',
    type: MissileSiteType.defenseIndustry,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 32.6200,
    lng: 51.6200,
    country: 'IR',
    operator: 'MODAFL',
    description:
        'Centrifuge component manufacturing for Natanz enrichment program. '
        'Also produces specialized missile parts. Underground production '
        'tunnels may remain intact.',
    sourceLabel: 'CENTCOM / IAEA [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-04',
    strikeDetails:
        'USAF strike on surface buildings. Underground tunnel entrances '
        'collapsed but production status uncertain.',
  ),

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 8 — DRONE / UAV BASES (3 targets)
  // ═══════════════════════════════════════════════════════════════════

  MissileSite(
    id: 'ir-kashan-drone',
    name: 'Kashan UAV / Shahed-136 Production',
    nameLocal: '\u06A9\u0627\u0634\u0627\u0646',
    type: MissileSiteType.droneBase,
    status: MissileSiteStatus.destroyed,
    lat: 33.8950,
    lng: 51.5770,
    country: 'IR',
    operator: 'IRGC-AF',
    description:
        'Primary Shahed-136 one-way-attack drone production and staging '
        'facility. Also produces Shahed-129 MALE reconnaissance UAVs. '
        'Key node for drone supply to Russia and proxy groups.',
    sourceLabel: 'CENTCOM / ISW [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USAF B-2 strike. Production halls, drone storage, and launch '
        'rails destroyed. 50+ Shahed-136 bodies confirmed destroyed '
        'in imagery. Critical strategic target.',
  ),

  MissileSite(
    id: 'ir-gorgan-drone',
    name: 'Gorgan Drone Facility',
    nameLocal: '\u06AF\u0631\u06AF\u0627\u0646',
    type: MissileSiteType.droneBase,
    status: MissileSiteStatus.partiallyDestroyed,
    lat: 36.9100,
    lng: 54.3700,
    country: 'IR',
    operator: 'IRGC-AF',
    description:
        'Northern drone operations base. Mohajer-6 and Ababil-series UAVs. '
        'Training center for IRGC drone operators. Assembly hangars '
        'struck but some facilities may remain operational.',
    sourceLabel: 'CENTCOM [A2]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-04',
    strikeDetails:
        'USAF JDAM/JSOW strike. Main assembly hangar and runway destroyed. '
        'Training building partially intact.',
  ),

  MissileSite(
    id: 'ir-isfahan-drone',
    name: 'Isfahan Mohajer UAV Wing',
    nameLocal: '\u0628\u0627\u0644 \u067E\u0647\u067E\u0627\u062F\u06CC \u0645\u0647\u0627\u062C\u0631',
    type: MissileSiteType.droneBase,
    status: MissileSiteStatus.destroyed,
    lat: 32.7800,
    lng: 51.8200,
    country: 'IR',
    operator: 'IRGC-AF',
    description:
        'IRGC-AF drone wing co-located with Khatami AFB. Mohajer-6 armed '
        'reconnaissance UAVs and Ababil-3 loitering munitions. '
        'Destroyed alongside the main air base.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'Destroyed in same strike package as Isfahan/Khatami AFB. '
        '8 Mohajer-6 and 12 Ababil-3 confirmed destroyed on ground.',
  ),

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 9 — IADS / RADAR / SAM SITES (5 targets)
  // ═══════════════════════════════════════════════════════════════════

  MissileSite(
    id: 'ir-tehran-s300',
    name: 'Tehran S-300PMU2 / Bavar-373 Battery',
    nameLocal: '\u067E\u062F\u0627\u0641\u0646\u062F \u0647\u0648\u0627\u06CC\u06CC \u062A\u0647\u0631\u0627\u0646',
    type: MissileSiteType.radarSam,
    status: MissileSiteStatus.destroyed,
    lat: 35.7400,
    lng: 51.5000,
    country: 'IR',
    operator: 'IRIAF Air Defense Force',
    description:
        'Primary air defense battery protecting Tehran. Russian-supplied '
        'S-300PMU2 and indigenous Bavar-373 long-range SAM. Engagement '
        'radars and command vehicles destroyed in SEAD/DEAD campaign.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USAF F-22 / EA-18G SEAD package. AGM-88G AARGM-ER destroyed '
        'engagement radar. Follow-up JDAM eliminated TELs. '
        'Tehran IADS rendered non-functional within 2 hours.',
  ),

  MissileSite(
    id: 'ir-isfahan-s300',
    name: 'Isfahan S-300 / Khordad-15 Battery',
    nameLocal: '\u067E\u062F\u0627\u0641\u0646\u062F \u0647\u0648\u0627\u06CC\u06CC \u0627\u0635\u0641\u0647\u0627\u0646',
    type: MissileSiteType.radarSam,
    status: MissileSiteStatus.destroyed,
    lat: 32.7000,
    lng: 51.7000,
    country: 'IR',
    operator: 'IRIAF Air Defense Force',
    description:
        'Multi-system air defense protecting Isfahan nuclear/military '
        'complex. S-300PMU2 and indigenous Khordad-15 medium-range SAM. '
        'Early warning radar co-located.',
    sourceLabel: 'CENTCOM / IDF [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'IAF F-35I launched AGM-142 Popeye stand-off. Engagement radars '
        'destroyed first, then USAF eliminated TELs and C2 vehicles.',
  ),

  MissileSite(
    id: 'ir-bushehr-s300',
    name: 'Bushehr S-300 Battery (NPP Defense)',
    nameLocal: '\u067E\u062F\u0627\u0641\u0646\u062F \u0646\u06CC\u0631\u0648\u06AF\u0627\u0647 \u0628\u0648\u0634\u0647\u0631',
    type: MissileSiteType.radarSam,
    status: MissileSiteStatus.destroyed,
    lat: 28.8300,
    lng: 50.8800,
    country: 'IR',
    operator: 'IRIAF Air Defense Force',
    description:
        'Dedicated S-300PMU2 battery defending Bushehr nuclear power plant. '
        'Battery was engaged after IRIAF air defense opened fire on '
        'Coalition aircraft.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USN EA-18G Growler SEAD + F/A-18E/F DEAD. All S-300 launchers '
        'and engagement radar destroyed. Bushehr NPP itself not targeted.',
  ),

  MissileSite(
    id: 'ir-natanz-bavar',
    name: 'Natanz Bavar-373 Battery',
    nameLocal: '\u0628\u0627\u0648\u0631-\u06F3\u06F7\u06F3 \u0646\u0637\u0646\u0632',
    type: MissileSiteType.radarSam,
    status: MissileSiteStatus.destroyed,
    lat: 33.7100,
    lng: 51.7200,
    country: 'IR',
    operator: 'IRIAF Air Defense Force',
    description:
        'Indigenous Bavar-373 long-range SAM battery defending Natanz '
        'nuclear enrichment facility. Iran\'s most advanced domestically '
        'produced air defense system.',
    sourceLabel: 'CENTCOM / IDF [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'First engagement of Bavar-373 in combat. System fired 2 missiles '
        'before being destroyed by USAF AGM-88G AARGM-ER. Post-strike '
        'analysis provided valuable intelligence on system capabilities.',
  ),

  MissileSite(
    id: 'ir-bandar-radar',
    name: 'Bandar Abbas Integrated Radar Complex',
    nameLocal: '\u0631\u0627\u062F\u0627\u0631 \u0628\u0646\u062F\u0631\u0639\u0628\u0627\u0633',
    type: MissileSiteType.radarSam,
    status: MissileSiteStatus.destroyed,
    lat: 27.2000,
    lng: 56.3500,
    country: 'IR',
    operator: 'IRIAF Air Defense Force',
    description:
        'Long-range early warning and surveillance radar complex. '
        'Ghadir phased-array and Sepehr over-the-horizon radar systems. '
        'Critical node for Iranian IADS — Strait of Hormuz coverage.',
    sourceLabel: 'CENTCOM BDA [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'USN TLAM first salvo target. Ghadir phased-array radar and all '
        'associated C2 buildings destroyed. IADS blind spot created '
        'over Strait of Hormuz within 30 minutes of H-hour.',
  ),

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY 10 — PROXY FORWARD BASES (5 targets)
  // ═══════════════════════════════════════════════════════════════════

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

  MissileSite(
    id: 'sy-t4-tiyas',
    name: 'T-4 / Tiyas Airbase',
    nameLocal: '\u0645\u0637\u0627\u0631 \u0627\u0644\u062A\u064A\u0641\u0648\u0631',
    type: MissileSiteType.proxyForward,
    status: MissileSiteStatus.destroyed,
    lat: 34.5200,
    lng: 37.6300,
    country: 'SY',
    operator: 'IRGC-QF / SAA',
    description:
        'IRGC drone operations base in central Syria. Hosted Shahed-129 '
        'and Mohajer-6 UAVs. Used for strikes on Coalition forces in '
        'eastern Syria and intelligence gathering.',
    sourceLabel: 'CENTCOM / IDF [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-01',
    strikeDetails:
        'IAF precision strike. IRGC drone hangars and arms depot destroyed. '
        'Syrian Air Force facilities on base not targeted.',
  ),

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

  MissileSite(
    id: 'ye-saada',
    name: 'Saada Missile & Drone Cache',
    nameLocal: '\u0635\u0639\u062F\u0629',
    type: MissileSiteType.proxyForward,
    status: MissileSiteStatus.destroyed,
    lat: 16.9400,
    lng: 43.7600,
    country: 'YE',
    operator: 'Ansar Allah (Houthi)',
    description:
        'Houthi weapons storage and BM staging area in Saada province. '
        'Iranian-supplied Toophan ATGMs, Burkan BMs, and Qasef-1 drones. '
        'Mountain cave storage.',
    sourceLabel: 'CENTCOM [A1]',
    sourceUrl: 'https://www.centcom.mil/MEDIA/PRESS-RELEASES/',
    lastStrikeDate: '2026-03-06',
    strikeDetails:
        'USAF B-1B strike with JASSM-ER stand-off munitions. '
        'Cave entrances collapsed. Weapons cache assessed destroyed.',
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

int get missileSitesUnknown =>
    iranianMissileSites.where((s) => s.status == MissileSiteStatus.unknown).length;

int get missileSitesTotal => iranianMissileSites.length;
