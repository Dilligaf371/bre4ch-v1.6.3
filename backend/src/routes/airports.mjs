// =============================================================================
// BRE4CH v2 - Airport Status API
// Real-time airport status from ICAO NOTAMs + FAA TFRS + headline analysis
//
// GET /api/airports/status  → all airports with live status
// =============================================================================

import { Router } from 'express';

const router = Router();

// ── Regional airports (ICAO codes) ──────────────────────────────

const AIRPORTS = [
  // UAE
  { icao: 'OMDB', iata: 'DXB', name: 'Dubai Intl', country: 'AE' },
  { icao: 'OMAA', iata: 'AUH', name: 'Abu Dhabi Intl', country: 'AE' },
  { icao: 'OMSJ', iata: 'SHJ', name: 'Sharjah Intl', country: 'AE' },
  { icao: 'OMDW', iata: 'DWC', name: 'Al Maktoum Intl', country: 'AE' },
  { icao: 'OMRK', iata: 'RKT', name: 'RAK Intl', country: 'AE' },
  // KSA
  { icao: 'OEJN', iata: 'JED', name: 'King Abdulaziz Intl', country: 'SA' },
  { icao: 'OERK', iata: 'RUH', name: 'King Khalid Intl', country: 'SA' },
  { icao: 'OEDF', iata: 'DMM', name: 'King Fahd Intl', country: 'SA' },
  { icao: 'OEMA', iata: 'MED', name: 'Madinah Intl', country: 'SA' },
  // Oman
  { icao: 'OOMS', iata: 'MCT', name: 'Muscat Intl', country: 'OM' },
  { icao: 'OOSA', iata: 'SLL', name: 'Salalah', country: 'OM' },
  // Qatar
  { icao: 'OTHH', iata: 'DOH', name: 'Hamad Intl', country: 'QA' },
  // Bahrain
  { icao: 'OBBI', iata: 'BAH', name: 'Bahrain Intl', country: 'BH' },
  // Israel
  { icao: 'LLBG', iata: 'TLV', name: 'Ben Gurion Intl', country: 'IL' },
  { icao: 'LLER', iata: 'ETH', name: 'Ramon Intl', country: 'IL' },
  // Lebanon
  { icao: 'OLBA', iata: 'BEY', name: 'Rafic Hariri Intl', country: 'LB' },
];

// ── NOTAM keywords that indicate closures/restrictions ──────────

const CLOSURE_KEYWORDS = [
  'CLSD', 'CLOSED', 'AD CLSD', 'RWY CLSD',
  'APRN CLSD', 'TWY CLSD', 'NOT AVBL',
];

const RESTRICTION_KEYWORDS = [
  'RESTRICTED', 'AIRSPACE CLOSED', 'NOTAM',
  'TFR', 'FIR CLSD', 'CTR CLSD',
  'MILITARY ACTIVITY', 'DRONE ACTIVITY',
  'LIMITED', 'DIVERSION', 'ALTERNATE',
];

const GROUND_STOP_KEYWORDS = [
  'GROUND STOP', 'GDP', 'GROUND DELAY',
  'FLOW CONTROL', 'SLOT RESTRICTION',
];

// ── Cache ────────────────────────────────────────────────────────

let cachedStatus = null;
let cacheTime = 0;
const CACHE_TTL = 90_000; // 90s

// ── Fetch NOTAMs from FAA DINS (public, no auth) ────────────────

async function fetchNotamsForAirport(icao) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);
    const url = `https://www.notams.faa.gov/dinsQueryWeb/queryRetrievalMapAction.do?reportType=Raw&retrieveLocId=${icao}&actionType=notamRetrievalByICAOs`;
    const res = await fetch(url, {
      headers: { 'User-Agent': 'BRE4CH-ROAR/1.0' },
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!res.ok) return [];
    const text = await res.text();

    // Extract NOTAM text blocks
    const notams = [];
    const regex = /NOTAM\s*\d*[^]*?(?=NOTAM\s*\d|$)/gi;
    let match;
    while ((match = regex.exec(text)) !== null) {
      notams.push(match[0].trim());
    }
    return notams;
  } catch {
    return [];
  }
}

// ── Analyze NOTAMs to determine airport status ──────────────────

function analyzeStatus(notams, icao) {
  const allText = notams.join(' ').toUpperCase();

  // Check for full closure
  for (const kw of CLOSURE_KEYWORDS) {
    if (allText.includes(kw)) {
      return {
        status: 'CLOSED',
        traffic: 'SUSPENDED',
        notamCount: notams.length,
        reason: `NOTAM: ${kw} detected`,
      };
    }
  }

  // Check for ground stops / delays
  for (const kw of GROUND_STOP_KEYWORDS) {
    if (allText.includes(kw)) {
      return {
        status: 'RESTRICTED',
        traffic: 'DELAYED',
        notamCount: notams.length,
        reason: `NOTAM: ${kw}`,
      };
    }
  }

  // Check for restrictions
  let restrictionCount = 0;
  for (const kw of RESTRICTION_KEYWORDS) {
    if (allText.includes(kw)) restrictionCount++;
  }

  if (restrictionCount >= 3) {
    return {
      status: 'RESTRICTED',
      traffic: 'DISRUPTED',
      notamCount: notams.length,
      reason: `${restrictionCount} restriction NOTAMs active`,
    };
  }

  if (notams.length > 5) {
    return {
      status: 'OPEN',
      traffic: 'CAUTION',
      notamCount: notams.length,
      reason: `${notams.length} active NOTAMs — elevated activity`,
    };
  }

  return {
    status: 'OPEN',
    traffic: 'NORMAL',
    notamCount: notams.length,
    reason: notams.length > 0 ? `${notams.length} routine NOTAMs` : 'No active NOTAMs',
  };
}

// ── Headline-based override (from cached headlines) ─────────────

function headlineOverrides(headlines) {
  const overrides = {};
  if (!headlines || !headlines.length) return overrides;

  for (const h of headlines) {
    const title = (h.title || '').toLowerCase();

    // Dubai airport
    if ((title.includes('dubai') || title.includes('dxb')) &&
        (title.includes('airport') || title.includes('closed') || title.includes('shut') || title.includes('suspended'))) {
      if (title.includes('closed') || title.includes('shut') || title.includes('suspended')) {
        overrides['OMDB'] = { status: 'CLOSED', traffic: 'SUSPENDED', reason: `HEADLINE: ${h.title}`, source: h.source };
      } else if (title.includes('divert') || title.includes('delay')) {
        overrides['OMDB'] = { status: 'RESTRICTED', traffic: 'DISRUPTED', reason: `HEADLINE: ${h.title}`, source: h.source };
      }
    }

    // Ben Gurion
    if ((title.includes('ben gurion') || title.includes('tlv') || title.includes('tel aviv airport')) &&
        (title.includes('closed') || title.includes('shut') || title.includes('suspended') || title.includes('divert'))) {
      overrides['LLBG'] = { status: 'CLOSED', traffic: 'SUSPENDED', reason: `HEADLINE: ${h.title}`, source: h.source };
    }

    // Beirut
    if ((title.includes('beirut') || title.includes('rafic hariri') || title.includes('bey')) &&
        (title.includes('closed') || title.includes('shut') || title.includes('strike') || title.includes('damaged'))) {
      overrides['OLBA'] = { status: 'CLOSED', traffic: 'SUSPENDED', reason: `HEADLINE: ${h.title}`, source: h.source };
    }

    // Generic airspace closure
    if (title.includes('airspace') && title.includes('closed')) {
      if (title.includes('iran')) {
        // No Iranian airports in our list, but note it
      }
      if (title.includes('israel')) {
        overrides['LLBG'] = overrides['LLBG'] || { status: 'RESTRICTED', traffic: 'DISRUPTED', reason: `HEADLINE: ${h.title}`, source: h.source };
        overrides['LLER'] = overrides['LLER'] || { status: 'RESTRICTED', traffic: 'DISRUPTED', reason: `HEADLINE: ${h.title}`, source: h.source };
      }
      if (title.includes('lebanon')) {
        overrides['OLBA'] = overrides['OLBA'] || { status: 'RESTRICTED', traffic: 'DISRUPTED', reason: `HEADLINE: ${h.title}`, source: h.source };
      }
    }
  }

  return overrides;
}

// ── Main endpoint ───────────────────────────────────────────────

router.get('/airports/status', async (req, res) => {
  const now = Date.now();

  // Return cache if fresh
  if (cachedStatus && (now - cacheTime) < CACHE_TTL) {
    return res.json({ ...cachedStatus, cached: true });
  }

  try {
    // Fetch NOTAMs for all airports in parallel
    const notamResults = await Promise.allSettled(
      AIRPORTS.map(async (ap) => {
        const notams = await fetchNotamsForAirport(ap.icao);
        const analysis = analyzeStatus(notams, ap.icao);
        return { ...ap, ...analysis };
      })
    );

    // Get headline overrides (from sources route if available)
    let headlines = [];
    try {
      // Import cached headlines from sources module
      const sourcesModule = await import('./sources.mjs');
      if (sourcesModule.getCachedHeadlines) {
        headlines = sourcesModule.getCachedHeadlines();
      }
    } catch { /* sources not available */ }

    const overrides = headlineOverrides(headlines);

    // Build results
    const airports = notamResults.map((r) => {
      if (r.status === 'fulfilled') {
        const ap = r.value;
        // Apply headline overrides if they indicate worse status
        if (overrides[ap.icao]) {
          const ov = overrides[ap.icao];
          // Only override if headline indicates worse status
          if (ov.status === 'CLOSED' || (ov.status === 'RESTRICTED' && ap.status === 'OPEN')) {
            return { ...ap, ...ov, notamCount: ap.notamCount, headlineOverride: true };
          }
        }
        return ap;
      }
      // Fallback for failed requests
      const ap = AIRPORTS.find(a => true); // shouldn't happen
      return { ...ap, status: 'UNKNOWN', traffic: 'UNKNOWN', notamCount: 0, reason: 'NOTAM fetch failed' };
    });

    const result = {
      airports,
      count: airports.length,
      lastRefresh: new Date().toISOString(),
      open: airports.filter(a => a.status === 'OPEN').length,
      restricted: airports.filter(a => a.status === 'RESTRICTED').length,
      closed: airports.filter(a => a.status === 'CLOSED').length,
      cached: false,
    };

    cachedStatus = result;
    cacheTime = now;
    res.json(result);
  } catch (err) {
    console.error(`[AIRPORTS] Error: ${err.message}`);
    // Return last cache or empty
    if (cachedStatus) {
      return res.json({ ...cachedStatus, cached: true, stale: true });
    }
    res.status(500).json({ error: 'Airport status fetch failed' });
  }
});

export default router;
