// =============================================================================
// BRE4CH — Defense Stats Auto-Scraper (zero-cost, regex-only)
//
// Hybrid approach:
//   1. Direct RSS feeds (Al Jazeera, Reuters, AP…) → real URLs → fetch body → regex
//   2. Google News RSS titles → regex on title text only (no body fetch)
//
// Schedule: 06:00 & 18:00 UAE time (02:00 & 14:00 UTC) daily
// Cost: $0 — pure fetch + regex
// =============================================================================

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { broadcast } from '../services/ws-server.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const DATA_PATH = join(__dirname, '..', 'data', 'defense-stats.json');

const SCHEDULE_HOURS = [2, 14]; // 06:00 & 18:00 UAE time (UTC+4)
const FETCH_TIMEOUT = 12_000;

// ── System / country config ──────────────────────────────────────

const COUNTRY_KEYWORDS = {
  'ad-uae-dhafra':  ['uae', 'emirates', 'emirati', 'al dhafra', 'dhafra', 'thaad'],
  'ad-kw-arifjan':  ['kuwait', 'kuwaiti', 'arifjan'],
  'ad-bh-nsa':      ['bahrain', 'bahraini', 'bdf', 'manama'],
  'ad-qa-udeid':    ['qatar', 'qatari', 'al udeid', 'udeid'],
  'ad-ksa-riyadh':  ['saudi', 'ksa', 'riyadh', 'kingdom of saudi'],
  'ad-om-muscat':   ['oman', 'omani', 'muscat', 'duqm'],
  'ad-il-center':   ['israel', 'israeli', 'idf', 'iron dome', 'arrow', 'david'],
  'ad-us-aegis':    ['centcom', 'aegis', 'u.s. navy', 'us navy', 'sm-3'],
};

// ── Direct RSS feeds (give real article URLs) ────────────────────

const DIRECT_FEEDS = [
  { url: 'https://www.aljazeera.com/xml/rss/all.xml', name: 'Al Jazeera' },
  { url: 'https://rss.nytimes.com/services/xml/rss/nyt/MiddleEast.xml', name: 'NYT Middle East' },
  { url: 'https://feeds.bbci.co.uk/news/world/middle_east/rss.xml', name: 'BBC Middle East' },
  { url: 'https://www.timesofisrael.com/feed/', name: 'Times of Israel' },
  { url: 'https://www.jpost.com/rss/rssfeedsfrontpage.aspx', name: 'Jerusalem Post' },
];

// ── Google News queries (title-only extraction) ──────────────────

const GNEWS_QUERIES = [
  '"intercepted" "ballistic missile" (UAE OR Kuwait OR Bahrain OR Qatar OR Saudi)',
  '"intercepted" "drone" (UAE OR Kuwait OR Bahrain OR Israel)',
  '"air defense" "intercepted" (CENTCOM OR coalition)',
  '"Iron Dome" OR "THAAD" intercepted',
];

// Defense relevance keywords — article must contain at least one
const DEFENSE_KEYWORDS = [
  'intercept', 'intercepted', 'interception',
  'shot down', 'destroyed', 'neutralized', 'downed',
  'air defense', 'air defence', 'missile defense',
  'ballistic', 'cruise missile', 'drone', 'uav',
  'iron dome', 'thaad', 'patriot', 'arrow', 'aegis',
];

// ── Number parser ────────────────────────────────────────────────

function parseNum(str) {
  if (!str) return null;
  const cleaned = str.replace(/,/g, '').trim();
  const n = parseInt(cleaned, 10);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

// ── Regex extraction engine ──────────────────────────────────────

function extractFromText(text) {
  if (!text || text.length < 30) return null;

  let ballistic = null;
  let cruise = null;
  let drone = null;
  let total = null;

  // ── Triple: "X ballistic … Y cruise … Z drones" ──
  const triple = text.match(
    /(\d[\d,]*)\s*ballistic[^.]{0,80}?(\d[\d,]*)\s*cruise[^.]{0,80}?(\d[\d,]*)\s*(?:drone|uav)s?/i
  );
  if (triple) {
    ballistic = parseNum(triple[1]);
    cruise = parseNum(triple[2]);
    drone = parseNum(triple[3]);
  }

  // ── Combined: "X missiles and Y drones" ──
  if (ballistic === null && drone === null) {
    const combined = text.match(
      /(\d[\d,]*)\s*(?:ballistic\s+)?missiles?\s*(?:and|,)\s*(\d[\d,]*)\s*(?:drone|uav)s?\s*(?:intercepted|destroyed|neutralized|shot\s*down|downed)/i
    ) || text.match(
      /(?:intercepted|destroyed|neutralized|shot\s*down|downed)\s*(\d[\d,]*)\s*(?:ballistic\s+)?missiles?\s*(?:and|,)\s*(\d[\d,]*)\s*(?:drone|uav)s?/i
    );
    if (combined) {
      ballistic = parseNum(combined[1]);
      drone = parseNum(combined[2]);
    }
  }

  // ── Individual patterns ──

  // Ballistic
  if (ballistic === null) {
    const m = text.match(
      /(\d[\d,]*)\s*(?:ballistic\s*missiles?|BMs?)\s*(?:were\s+)?(?:intercepted|destroyed|neutralized|shot\s*down|engaged)/i
    ) || text.match(
      /(?:intercepted|destroyed|neutralized|shot\s*down|engaged)\s*(\d[\d,]*)\s*(?:ballistic\s*missiles?|BMs?)/i
    );
    if (m) ballistic = parseNum(m[1]);
  }

  // Cruise
  if (cruise === null) {
    const m = text.match(
      /(\d[\d,]*)\s*cruise\s*missiles?\s*(?:were\s+)?(?:intercepted|destroyed|neutralized|shot\s*down|engaged)/i
    ) || text.match(
      /(?:intercepted|destroyed|neutralized|shot\s*down|engaged)\s*(\d[\d,]*)\s*cruise\s*missiles?/i
    );
    if (m) cruise = parseNum(m[1]);
  }

  // Drones
  if (drone === null) {
    const m = text.match(
      /(\d[\d,]*)\s*(?:drone|uav|unmanned)s?\s*(?:were\s+)?(?:intercepted|destroyed|neutralized|shot\s*down|engaged|downed)/i
    ) || text.match(
      /(?:intercepted|destroyed|neutralized|shot\s*down|engaged|downed)\s*(\d[\d,]*)\s*(?:drone|uav|unmanned)s?/i
    );
    if (m) drone = parseNum(m[1]);
  }

  // Total
  const tm = text.match(
    /(?:total\s*(?:of\s*)?)(\d[\d,]*)\s*(?:threat|intercept|projectile|aerial\s*target|attack)s?\s*(?:intercepted|destroyed|neutralized)/i
  ) || text.match(
    /(\d[\d,]*)\s*(?:total\s+)?interceptions/i
  );
  if (tm) total = parseNum(tm[1]);

  // Need at least one category (not just total)
  if (ballistic === null && cruise === null && drone === null) return null;

  const b = ballistic ?? 0;
  const c = cruise ?? 0;
  const d = drone ?? 0;
  const computed = b + c + d;

  return {
    ballisticIntercepted: b,
    cruiseIntercepted: c,
    droneIntercepted: d,
    totalIntercepted: total ?? computed,
  };
}

/**
 * Identify which system/country an article belongs to.
 * Returns system ID or null.
 */
function identifySystem(text) {
  const lower = text.toLowerCase();
  for (const [systemId, keywords] of Object.entries(COUNTRY_KEYWORDS)) {
    if (keywords.some(kw => lower.includes(kw))) return systemId;
  }
  return null;
}

/**
 * Check if text is defense-related.
 */
function isDefenseRelated(text) {
  const lower = text.toLowerCase();
  return DEFENSE_KEYWORDS.some(kw => lower.includes(kw));
}

// ── RSS fetcher ──────────────────────────────────────────────────

async function fetchRSS(url, maxItems = 15) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT);
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'BRE4CH-ROAR/2.0',
        'Accept': 'application/rss+xml, application/xml, text/xml',
      },
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!res.ok) return [];
    const xml = await res.text();

    const items = [];
    const itemRegex = /<(?:item|entry)>([\s\S]*?)<\/(?:item|entry)>/gi;
    let match;
    while ((match = itemRegex.exec(xml)) !== null && items.length < maxItems) {
      const block = match[1];
      const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]><\/title>/i)?.[1]
        || block.match(/<title[^>]*>(.*?)<\/title>/i)?.[1] || '').trim();
      const link = (block.match(/<link[^>]*href="([^"]*)"[^>]*>/i)?.[1]
        || block.match(/<link>([^<]+)<\/link>/i)?.[1] || '').trim();
      const pubDate = (block.match(/<(?:pubDate|published|updated)>(.*?)<\/(?:pubDate|published|updated)>/i)?.[1] || '').trim();
      const source = (block.match(/<source[^>]*>(.*?)<\/source>/i)?.[1] || '').trim();
      const desc = (block.match(/<description><!\[CDATA\[(.*?)\]\]><\/description>/i)?.[1]
        || block.match(/<description>(.*?)<\/description>/i)?.[1] || '').trim();
      if (title) items.push({ title, link, pubDate, source, desc });
    }
    return items;
  } catch (err) {
    console.error(`[DEFENSE-SCRAPER] RSS error (${url}): ${err.message}`);
    return [];
  }
}

// ── Article body fetcher ─────────────────────────────────────────

async function fetchArticleText(url) {
  // Skip Google News URLs — they don't resolve
  if (url.includes('news.google.com')) return '';

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT);
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': 'text/html',
      },
      signal: controller.signal,
      redirect: 'follow',
    });
    clearTimeout(timeout);

    if (!res.ok) return '';
    const html = await res.text();

    return html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<nav[^>]*>[\s\S]*?<\/nav>/gi, '')
      .replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 8000);
  } catch {
    return '';
  }
}

// ── Validation ───────────────────────────────────────────────────

function loadCurrentStats() {
  try {
    return JSON.parse(readFileSync(DATA_PATH, 'utf-8'));
  } catch {
    return { stats: {} };
  }
}

function saveStats(data) {
  writeFileSync(DATA_PATH, JSON.stringify(data, null, 2), 'utf-8');
}

function validateExtraction(systemId, extracted, currentStats) {
  const current = currentStats[systemId];
  if (!current) return null;

  const { ballisticIntercepted: b, cruiseIntercepted: c, droneIntercepted: d, totalIntercepted: t } = extracted;

  // Monotonically increasing
  if (
    b < current.ballisticIntercepted ||
    c < current.cruiseIntercepted ||
    d < current.droneIntercepted ||
    t < current.totalIntercepted
  ) return null;

  // No change
  if (
    b === current.ballisticIntercepted &&
    c === current.cruiseIntercepted &&
    d === current.droneIntercepted
  ) return null;

  // Sanity: total ≈ sum
  const computed = b + c + d;
  if (t > 0 && computed > 0) {
    const diff = Math.abs(t - computed);
    if (diff > 5 && diff / t > 0.10) return null;
  }

  return {
    ballisticIntercepted: b,
    cruiseIntercepted: c,
    droneIntercepted: d,
    totalIntercepted: t || computed,
    lastUpdated: new Date().toISOString(),
  };
}

// ── Main scraper ─────────────────────────────────────────────────

let _isRunning = false;
let _lastRun = null;
let _lastResult = { articlesFound: 0, articlesProcessed: 0, statsUpdated: 0, errors: 0 };

export async function runDefenseScraper() {
  if (_isRunning) return _lastResult;

  _isRunning = true;
  _lastRun = new Date().toISOString();
  const result = { articlesFound: 0, articlesProcessed: 0, statsUpdated: 0, errors: 0, updates: [] };

  console.log(`[DEFENSE-SCRAPER] Starting scrape at ${_lastRun}`);

  try {
    const candidates = []; // { systemId, title, text, source }

    // ── Source 1: Direct RSS feeds ──
    for (const feed of DIRECT_FEEDS) {
      try {
        const items = await fetchRSS(feed.url, 20);
        for (const item of items) {
          const combined = `${item.title} ${item.desc || ''}`;
          if (!isDefenseRelated(combined)) continue;
          const systemId = identifySystem(combined);
          if (!systemId) continue;

          // Freshness check
          try {
            if (Date.now() - new Date(item.pubDate).getTime() > 72 * 3600_000) continue;
          } catch { continue; }

          candidates.push({
            systemId,
            title: item.title,
            link: item.link,
            source: feed.name,
            canFetchBody: !item.link.includes('news.google.com'),
          });
        }
      } catch { result.errors++; }
      await sleep(300);
    }

    // ── Source 2: Google News RSS (title-only) ──
    for (const query of GNEWS_QUERIES) {
      try {
        const encoded = encodeURIComponent(query);
        const url = `https://news.google.com/rss/search?q=${encoded}&hl=en&gl=US&ceid=US:en`;
        const items = await fetchRSS(url, 5);
        for (const item of items) {
          if (!isDefenseRelated(item.title)) continue;
          const systemId = identifySystem(item.title);
          if (!systemId) continue;

          try {
            if (Date.now() - new Date(item.pubDate).getTime() > 72 * 3600_000) continue;
          } catch { continue; }

          candidates.push({
            systemId,
            title: item.title,
            link: item.link,
            source: item.source || 'Google News',
            canFetchBody: false, // Google News links don't resolve
          });
        }
      } catch { result.errors++; }
      await sleep(400);
    }

    // Deduplicate
    const seen = new Set();
    const unique = candidates.filter(c => {
      const key = c.title.toLowerCase().slice(0, 80);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });

    result.articlesFound = unique.length;
    console.log(`[DEFENSE-SCRAPER] ${unique.length} unique defense articles found`);

    if (unique.length === 0) {
      _isRunning = false;
      _lastResult = result;
      return result;
    }

    // ── Process each candidate ──
    const data = loadCurrentStats();

    for (const article of unique) {
      result.articlesProcessed++;

      // Build text: title + body (if fetchable)
      let fullText = article.title;
      if (article.canFetchBody && article.link) {
        const body = await fetchArticleText(article.link);
        if (body.length > 100) fullText = body;
        await sleep(300);
      }

      const extracted = extractFromText(fullText);
      if (!extracted) continue;

      const validated = validateExtraction(article.systemId, extracted, data.stats);
      if (!validated) continue;

      const oldTotal = data.stats[article.systemId]?.totalIntercepted || 0;
      data.stats[article.systemId] = validated;
      result.statsUpdated++;
      result.updates.push({
        systemId: article.systemId,
        oldTotal,
        newTotal: validated.totalIntercepted,
        source: article.source,
        title: article.title.slice(0, 120),
      });

      console.log(`[DEFENSE-SCRAPER] ✓ UPDATED ${article.systemId}: ${oldTotal} → ${validated.totalIntercepted} (${article.source})`);
    }

    if (result.statsUpdated > 0) {
      saveStats(data);
      console.log(`[DEFENSE-SCRAPER] Saved ${result.statsUpdated} updates`);
      // Push updated stats to all connected clients via WebSocket
      broadcast('stats', data);
    }
  } catch (err) {
    result.errors++;
    console.error(`[DEFENSE-SCRAPER] Fatal: ${err.message}`);
  }

  _isRunning = false;
  _lastResult = result;
  console.log(`[DEFENSE-SCRAPER] Done — found: ${result.articlesFound}, processed: ${result.articlesProcessed}, updated: ${result.statsUpdated}`);
  return result;
}

// ── Scheduler (06:00 & 18:00 UAE = 02:00 & 14:00 UTC) ───────────

let _scraperStarted = false;
let _nextRunAt = null;

/**
 * Compute the next scheduled scrape time.
 */
function getNextScheduledTime(from = new Date()) {
  const candidates = [];
  for (const h of SCHEDULE_HOURS) {
    const t = new Date(from);
    t.setUTCHours(h, 0, 0, 0);
    if (t.getTime() > from.getTime()) {
      candidates.push(t);
    }
    const t2 = new Date(from);
    t2.setUTCDate(t2.getUTCDate() + 1);
    t2.setUTCHours(h, 0, 0, 0);
    candidates.push(t2);
  }
  candidates.sort((a, b) => a.getTime() - b.getTime());
  return candidates[0];
}

/**
 * Recursively schedule the next scrape run.
 */
function scheduleNext() {
  const next = getNextScheduledTime();
  const delayMs = next.getTime() - Date.now();
  _nextRunAt = next.toISOString();
  const hhmm = `${next.getUTCHours().toString().padStart(2, '0')}:00`;
  console.log(`[DEFENSE-SCRAPER] Next scrape at ${next.toISOString()} (${hhmm} UTC, in ${Math.round(delayMs / 60000)}min)`);

  setTimeout(async () => {
    try {
      await runDefenseScraper();
    } catch (err) {
      console.error(`[DEFENSE-SCRAPER] Scheduled scrape error: ${err.message}`);
    }
    scheduleNext();
  }, delayMs);
}

export function startDefenseScraperScheduler() {
  if (_scraperStarted) return;
  _scraperStarted = true;
  console.log(`[DEFENSE-SCRAPER] Scheduler started — schedule: ${SCHEDULE_HOURS.map(h => h + ':00').join(' & ')} UTC (06:00 & 18:00 UAE) — zero-cost regex mode`);

  // Initial scrape 60s after boot
  setTimeout(() => runDefenseScraper(), 60_000);

  // Fixed-time schedule
  scheduleNext();
}

// ── Status ───────────────────────────────────────────────────────

export function getScraperStatus() {
  return {
    lastRun: _lastRun,
    isRunning: _isRunning,
    lastResult: _lastResult,
    schedule: SCHEDULE_HOURS.map(h => `${h.toString().padStart(2, '0')}:00 UTC`),
    nextRunAt: _nextRunAt,
    mode: 'regex (zero-cost)',
    sources: {
      directFeeds: DIRECT_FEEDS.length,
      googleNewsQueries: GNEWS_QUERIES.length,
    },
  };
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
