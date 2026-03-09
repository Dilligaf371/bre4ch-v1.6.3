import { getCachedTweets } from "../scrapers/x-scraper.mjs";
import { Router } from 'express';
import { LIVEUAMAP_API_KEY, SOURCE_REFRESH_INTERVAL } from '../config.mjs';
import { scanAndNotify } from './notifications.mjs';

const router = Router();

// ─── RSS Feed Parser (lightweight, no deps) ───
async function fetchRSSHeadlines(feedUrl, sourceName, maxItems = 10) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12_000);
    const res = await fetch(feedUrl, {
      headers: { 'User-Agent': 'BRE4CH-ROAR/1.0', Accept: 'application/rss+xml, application/xml, text/xml' },
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const xml = await res.text();

    const items = [];
    const itemRegex = /<(?:item|entry)>([\s\S]*?)<\/(?:item|entry)>/gi;
    let match;
    while ((match = itemRegex.exec(xml)) !== null && items.length < maxItems) {
      const block = match[1];
      const title = block.match(/<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/title>/i)?.[1]?.trim() || '';
      const link = block.match(/<link[^>]*href="([^"]*)"[^>]*>/i)?.[1]
        || block.match(/<link[^>]*>(.*?)<\/link>/i)?.[1]?.trim() || '';
      const pubDate = block.match(/<(?:pubDate|published|updated)>(.*?)<\/(?:pubDate|published|updated)>/i)?.[1]?.trim() || '';
      if (title) items.push({ title, link, pubDate, source: sourceName });
    }
    return items;
  } catch (err) {
    console.error(`[REFRESH] ${sourceName} RSS error: ${err.message}`);
    return [];
  }
}

// ─── Source status tracking ───
const sourceStatus = {
  lastRefresh: null,
  nextRefresh: null,
  refreshCount: 0,
  sources: {
    liveuamap: { status: 'idle', lastFetch: null, events: 0, error: null },
    // International wire services
    centcom:      { status: 'idle', lastFetch: null, items: 0, error: null },
    reuters:      { status: 'idle', lastFetch: null, items: 0, error: null },
    ap:           { status: 'idle', lastFetch: null, items: 0, error: null },
    bbc:          { status: 'idle', lastFetch: null, items: 0, error: null },
    aljazeera:    { status: 'idle', lastFetch: null, items: 0, error: null },
    bloomberg:    { status: 'idle', lastFetch: null, items: 0, error: null },
    dod:          { status: 'idle', lastFetch: null, items: 0, error: null },
    idf:          { status: 'idle', lastFetch: null, items: 0, error: null },
    // GCC newspapers — UAE
    khaleejtimes: { status: 'idle', lastFetch: null, items: 0, error: null },
    thenational:  { status: 'idle', lastFetch: null, items: 0, error: null },
    gulfnews:     { status: 'idle', lastFetch: null, items: 0, error: null },
    gulftoday:    { status: 'idle', lastFetch: null, items: 0, error: null },
    emirates247:  { status: 'idle', lastFetch: null, items: 0, error: null },
    // GCC newspapers — Saudi
    arabnews:     { status: 'idle', lastFetch: null, items: 0, error: null },
    saudigazette: { status: 'idle', lastFetch: null, items: 0, error: null },
    // GCC newspapers — Qatar
    gulftimes:       { status: 'idle', lastFetch: null, items: 0, error: null },
    peninsulaqatar:  { status: 'idle', lastFetch: null, items: 0, error: null },
    qatartribune:    { status: 'idle', lastFetch: null, items: 0, error: null },
    // GCC newspapers — Bahrain
    gulfdailynews:   { status: 'idle', lastFetch: null, items: 0, error: null },
    dailytribunebh:  { status: 'idle', lastFetch: null, items: 0, error: null },
    // GCC newspapers — Oman
    timesofoman:  { status: 'idle', lastFetch: null, items: 0, error: null },
    omanobserver: { status: 'idle', lastFetch: null, items: 0, error: null },
    // GCC official agencies
    wam:          { status: 'idle', lastFetch: null, items: 0, error: null },
    spa:          { status: 'idle', lastFetch: null, items: 0, error: null },
    qna:          { status: 'idle', lastFetch: null, items: 0, error: null },
    bna:          { status: 'idle', lastFetch: null, items: 0, error: null },
    kuna:         { status: 'idle', lastFetch: null, items: 0, error: null },
    omannews:     { status: 'idle', lastFetch: null, items: 0, error: null },
    // Israel
    timesofisrael: { status: 'idle', lastFetch: null, items: 0, error: null },
    jpost:        { status: 'idle', lastFetch: null, items: 0, error: null },
  },
  running: false,
};

// ─── Liveuamap cache ───
let liveuamapCache = { data: null, timestamp: 0 };
const CACHE_TTL = 60_000;

// ─── Individual source refreshers ───
async function refreshLiveuamap() {
  if (!LIVEUAMAP_API_KEY) {
    sourceStatus.sources.liveuamap = { status: 'no_key', lastFetch: null, events: 0, error: 'No API key' };
    return [];
  }
  sourceStatus.sources.liveuamap.status = 'fetching';
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15_000);
    const response = await fetch(`https://a.liveuamap.com/api/mpts?key=${LIVEUAMAP_API_KEY}&region=middleeast&limit=30`, {
      headers: { Accept: 'application/json', 'User-Agent': 'BRE4CH-ROAR/1.0' },
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!response.ok) throw new Error(`API ${response.status}`);
    const data = await response.json();
    const events = (data.events || data.mpts || data || []).map(evt => ({
      id: evt.id || `lua-${evt.timeDt || Date.now()}`,
      name: evt.name || evt.title || '',
      lat: parseFloat(evt.lat || 0),
      lng: parseFloat(evt.lng || 0),
      time: evt.timeDt || evt.time || '',
      source: evt.source || 'liveuamap',
      url: evt.url || '',
      region: evt.region || 'middleeast',
    }));

    liveuamapCache = { data: { events, source: 'liveuamap', region: 'middleeast', count: events.length, cached: false }, timestamp: Date.now() };
    sourceStatus.sources.liveuamap = { status: 'ok', lastFetch: Date.now(), events: events.length, error: null };
    return events;
  } catch (err) {
    sourceStatus.sources.liveuamap = { status: 'error', lastFetch: Date.now(), events: 0, error: err.message };
    return [];
  }
}

// Label map for Flutter sourceMap compatibility
const SOURCE_LABELS = {
  // International
  centcom: 'CENTCOM', bbc: 'BBC', aljazeera: 'Al Jazeera',
  reuters: 'Reuters', ap: 'AP', dod: 'DoD', idf: 'IDF',
  bloomberg: 'Bloomberg',
  // GCC newspapers — UAE
  khaleejtimes: 'Khaleej Times', thenational: 'The National',
  gulfnews: 'Gulf News', gulftoday: 'Gulf Today', emirates247: 'Emirates 24|7',
  // GCC newspapers — Saudi
  arabnews: 'Arab News', saudigazette: 'Saudi Gazette',
  // GCC newspapers — Qatar
  gulftimes: 'Gulf Times', peninsulaqatar: 'The Peninsula', qatartribune: 'Qatar Tribune',
  // GCC newspapers — Bahrain
  gulfdailynews: 'Gulf Daily News', dailytribunebh: 'Daily Tribune',
  // GCC newspapers — Oman
  timesofoman: 'Times of Oman', omanobserver: 'Oman Observer',
  // GCC agencies
  wam: 'WAM', spa: 'SPA', qna: 'QNA', bna: 'BNA',
  kuna: 'KUNA', omannews: 'Oman News',
  // Israel
  timesofisrael: 'Times of Israel', jpost: 'JPost',
};

async function refreshSource(name, feedUrl) {
  if (!sourceStatus.sources[name]) sourceStatus.sources[name] = { status: 'idle', lastFetch: null, items: 0, error: null };
  sourceStatus.sources[name].status = 'fetching';
  try {
    const label = SOURCE_LABELS[name] || name.charAt(0).toUpperCase() + name.slice(1);
    const items = await fetchRSSHeadlines(feedUrl, label, 10);
    sourceStatus.sources[name] = { status: 'ok', lastFetch: Date.now(), items: items.length, error: null };
    return items;
  } catch (err) {
    sourceStatus.sources[name] = { status: 'error', lastFetch: Date.now(), items: 0, error: err.message };
    return [];
  }
}

// ─── Headlines cache ───
let headlinesCache = { items: [], timestamp: 0 };

// ─── Master refresh ───
async function refreshAllSources() {
  if (sourceStatus.running) return sourceStatus;
  sourceStatus.running = true;
  console.log('[REFRESH] Refreshing all sources...');
  const start = Date.now();

  const RSS_SOURCES = [
    // ── International wire services ──
    { name: 'centcom',    url: 'https://news.google.com/rss/search?q=site:centcom.mil&hl=en-US&gl=US&ceid=US:en' },
    { name: 'reuters',    url: 'https://news.google.com/rss/search?q=Iran+military+site:reuters.com&hl=en-US&gl=US&ceid=US:en' },
    { name: 'ap',         url: 'https://news.google.com/rss/search?q=Iran+military+site:apnews.com&hl=en-US&gl=US&ceid=US:en' },
    { name: 'bbc',        url: 'https://feeds.bbci.co.uk/news/world/middle_east/rss.xml' },
    { name: 'aljazeera',  url: 'https://www.aljazeera.com/xml/rss/all.xml' },
    { name: 'bloomberg',  url: 'https://feeds.bloomberg.com/markets/news.rss' },
    { name: 'dod',        url: 'https://www.defense.gov/DesktopModules/ArticleCS/RSS.ashx?max=10&ContentType=1&Site=945' },
    { name: 'idf',        url: 'https://news.google.com/rss/search?q=IDF+Israel+military+Iran&hl=en-US&gl=US&ceid=US:en' },
    // ── GCC newspapers — UAE ──
    { name: 'khaleejtimes', url: 'https://www.khaleejtimes.com/stories.rss?botrequest=true' },
    { name: 'thenational',  url: 'https://www.thenationalnews.com/arc/outboundfeeds/rss/?outputType=xml' },
    { name: 'gulfnews',     url: 'https://news.google.com/rss/search?q=site:gulfnews.com&hl=en-US&gl=US&ceid=US:en' },
    { name: 'gulftoday',    url: 'https://news.google.com/rss/search?q=site:gulftoday.ae&hl=en-US&gl=US&ceid=US:en' },
    { name: 'emirates247',  url: 'https://news.google.com/rss/search?q=site:emirates247.com&hl=en-US&gl=US&ceid=US:en' },
    // ── GCC newspapers — Saudi ──
    { name: 'arabnews',     url: 'https://news.google.com/rss/search?q=site:arabnews.com&hl=en-US&gl=US&ceid=US:en' },
    { name: 'saudigazette', url: 'https://news.google.com/rss/search?q=site:saudigazette.com.sa&hl=en-US&gl=US&ceid=US:en' },
    // ── GCC newspapers — Qatar ──
    { name: 'gulftimes',      url: 'https://news.google.com/rss/search?q=site:gulf-times.com&hl=en-US&gl=US&ceid=US:en' },
    { name: 'peninsulaqatar', url: 'https://news.google.com/rss/search?q=site:thepeninsulaqatar.com&hl=en-US&gl=US&ceid=US:en' },
    { name: 'qatartribune',   url: 'https://news.google.com/rss/search?q=site:qatar-tribune.com&hl=en-US&gl=US&ceid=US:en' },
    // ── GCC newspapers — Bahrain ──
    { name: 'gulfdailynews',  url: 'https://news.google.com/rss/search?q=site:gdnonline.com&hl=en-US&gl=US&ceid=US:en' },
    { name: 'dailytribunebh', url: 'https://news.google.com/rss/search?q=site:newsofbahrain.com&hl=en-US&gl=US&ceid=US:en' },
    // ── GCC newspapers — Oman ──
    { name: 'timesofoman',  url: 'https://news.google.com/rss/search?q=site:timesofoman.com&hl=en-US&gl=US&ceid=US:en' },
    { name: 'omanobserver', url: 'https://news.google.com/rss/search?q=site:omanobserver.om&hl=en-US&gl=US&ceid=US:en' },
    // ── GCC official news agencies ──
    { name: 'wam',       url: 'https://news.google.com/rss/search?q=site:wam.ae&hl=en-US&gl=US&ceid=US:en' },
    { name: 'spa',       url: 'https://news.google.com/rss/search?q=site:spa.gov.sa&hl=en-US&gl=US&ceid=US:en' },
    { name: 'qna',       url: 'https://news.google.com/rss/search?q=site:qna.org.qa&hl=en-US&gl=US&ceid=US:en' },
    { name: 'bna',       url: 'https://news.google.com/rss/search?q=site:bna.bh&hl=en-US&gl=US&ceid=US:en' },
    { name: 'kuna',      url: 'https://news.google.com/rss/search?q=site:kuna.net.kw&hl=en-US&gl=US&ceid=US:en' },
    { name: 'omannews',  url: 'https://news.google.com/rss/search?q=site:omannews.gov.om&hl=en-US&gl=US&ceid=US:en' },
    // ── Israel ──
    { name: 'timesofisrael', url: 'https://news.google.com/rss/search?q=site:timesofisrael.com&hl=en-US&gl=US&ceid=US:en' },
    { name: 'jpost',         url: 'https://news.google.com/rss/search?q=site:jpost.com&hl=en-US&gl=US&ceid=US:en' },
  ];

  const results = await Promise.allSettled([
    refreshLiveuamap(),
    ...RSS_SOURCES.map(s => refreshSource(s.name, s.url)),
  ]);

  // Collect all headline items (skip liveuamap at index 0)
  const allItems = results.slice(1)
    .filter(r => r.status === 'fulfilled')
    .flatMap(r => r.value);
  const xTweets = getCachedTweets() || [];
  headlinesCache = { items: [...allItems, ...xTweets], timestamp: Date.now() };

  sourceStatus.lastRefresh = Date.now();
  sourceStatus.nextRefresh = Date.now() + SOURCE_REFRESH_INTERVAL;
  sourceStatus.refreshCount++;
  sourceStatus.running = false;

  const okCount = Object.values(sourceStatus.sources).filter(s => s.status === 'ok').length;
  console.log(`[REFRESH] Done in ${Date.now() - start}ms — ${okCount}/${Object.keys(sourceStatus.sources).length} sources — ${allItems.length} headlines`);

  // Scan new headlines for push notifications
  try { await scanAndNotify(); } catch (e) { console.error('[FCM] scanAndNotify error:', e.message); }

  return sourceStatus;
}

// ─── Routes ───
router.get('/liveuamap', async (req, res) => {
  if (!LIVEUAMAP_API_KEY) return res.status(503).json({ error: 'Liveuamap API key not configured' });

  if (liveuamapCache.data && (Date.now() - liveuamapCache.timestamp) < CACHE_TTL) {
    return res.json({ ...liveuamapCache.data, cached: true });
  }

  try {
    const region = req.query.region || 'middleeast';
    const count = Math.min(parseInt(req.query.count) || 30, 50);
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15_000);

    const response = await fetch(`https://a.liveuamap.com/api/mpts?key=${LIVEUAMAP_API_KEY}&region=${region}&limit=${count}`, {
      headers: { Accept: 'application/json', 'User-Agent': 'BRE4CH-ROAR/1.0' },
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!response.ok) throw new Error(`API ${response.status}`);
    const data = await response.json();
    const events = (data.events || data.mpts || data || []).map(evt => ({
      id: evt.id || `lua-${evt.timeDt || Date.now()}`,
      name: evt.name || evt.title || evt.description || '',
      lat: parseFloat(evt.lat || evt.latitude || 0),
      lng: parseFloat(evt.lng || evt.longitude || 0),
      time: evt.timeDt || evt.time || evt.created_at || '',
      source: evt.source || evt.src || 'liveuamap',
      url: evt.url || evt.link || '',
      region: evt.region || region,
    }));

    liveuamapCache = { data: { events, source: 'liveuamap', region, count: events.length, cached: false }, timestamp: Date.now() };
    res.json(liveuamapCache.data);
  } catch (error) {
    if (liveuamapCache.data) return res.json({ ...liveuamapCache.data, cached: true, stale: true });
    res.status(502).json({ error: error.message, fallback: true });
  }
});

router.get('/sources/status', (_req, res) => {
  res.json({ ...sourceStatus, intervalMs: SOURCE_REFRESH_INTERVAL, headlineCount: headlinesCache.items.length });
});

router.get('/sources/headlines', (req, res) => {
  const source = req.query.source;
  let items = headlinesCache.items;
  if (source) items = items.filter(i => i.source.toLowerCase().includes(source.toLowerCase()));
  res.json({ items, count: items.length, lastRefresh: headlinesCache.timestamp, cached: true });
});

router.post('/sources/refresh', async (_req, res) => {
  try {
    const status = await refreshAllSources();
    res.json({ ok: true, ...status, headlineCount: headlinesCache.items.length });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ─── Expose cached headlines for other routes ───
export function getCachedHeadlines() {
  return headlinesCache.items || [];
}

// ─── Start auto-refresh scheduler ───
export function startRefreshScheduler() {
  setTimeout(() => refreshAllSources(), 5000);
  setInterval(() => refreshAllSources(), SOURCE_REFRESH_INTERVAL);
  console.log(`[REFRESH] Scheduler active — every ${SOURCE_REFRESH_INTERVAL / 1000}s`);
}

export default router;
