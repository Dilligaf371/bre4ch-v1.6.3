// =============================================================================
// BRE4CH — X (Twitter) API v2 Filtered Stream
// Real-time streaming via persistent connection — tweets pushed instantly.
// Zero polling = near-zero cost (1 persistent connection).
//
// Requires: X_BEARER_TOKEN in .env
// Endpoints:
//   POST /2/tweets/search/stream/rules   — set filter rules
//   GET  /2/tweets/search/stream          — persistent stream
//
// Rate limits: 50 rules (Basic), 1 connection at a time
// Cost: stream connection itself is free — only counts toward monthly cap
// =============================================================================

import { X_BEARER_TOKEN, X_POLL_INTERVAL } from '../config.mjs';

// ── Mode: "stream" (default) or "poll" (for DRP / single-token constraint) ──
const X_MODE = process.env.X_MODE || 'stream';

// ── Accounts to monitor ─────────────────────────────────────────

const GOV_ACCOUNTS = [
  'modgovae',        // MOD UAE
  'WAaboron',        // WAM
  'modaboron_sa',    // MOD KSA
  'SPAaboron',       // SPA
  'IDF',             // IDF Spokesperson
  'IsraelMFA',       // MoFA Israel
  'CENTCOM',         // US Central Command
  'DeptofDefense',   // US DoD
];

const OSINT_ACCOUNTS = [
  'Conflicts',       // @Conflicts
  'IntelCrab',       // @IntelCrab
  'sentdefender',    // @sentdefender
  'OSINTdefender',   // @OSINTdefender
  'ELINTNews',       // @ELINTNews
];

// ── Map X handles to display labels ──────────────────────────────
const HANDLE_TO_SOURCE = {
  'modgovae':       '@modgovae',
  'waboron':        'WAM',          // lowercase for matching
  'waaboron':       'WAM',
  'modaboron_sa':   '@modaboron_sa',
  'spaboron':       'SPA',
  'spaaboron':      'SPA',
  'idf':            'IDF',
  'israelmfa':      '@IsraelMFA',
  'centcom':        'CENTCOM',
  'deptofdefense':  'DoD',
  'conflicts':      '@Conflicts',
  'intelcrab':      '@IntelCrab',
  'sentdefender':   '@sentdefender',
  'osintdefender':  '@OSINTdefender',
  'elintnews':      '@ELINTNews',
};

// ── Conflict keywords (STRICT: no country names — require military terms) ──
const CONFLICT_KEYWORDS = [
  'iran', 'israel', 'military', 'strike', 'missile', 'drone', 'intercept',
  'attack', 'war', 'defense', 'defence', 'bomb', 'killed', 'navy',
  'air force', 'centcom', 'houthi', 'hezbollah', 'gaza', 'yemen', 'lebanon',
  'ballistic', 'cruise missile', 'air defense', 'shot down', 'retaliat',
  'nuclear', 'irgc', 'coalition', 'operation', 'airstrike', 'rocket',
  'artillery', 'casualties', 'wounded', 'escalat', 'sanction', 'deploy',
  'evacuate', 'shelter', 'siren', 'alert', 'raid', 'target', 'threat',
  'combat', 'troops', 'militia', 'weapon', 'explosive', 'torpedo',
  'proxy', 'blockade', 'ceasefire', 'hostage', 'sabotage',
  'هجوم', 'صاروخ', 'طائرة مسيرة', 'ضربة', 'حرب', 'اعتراض', 'دفاع',
  'غارة', 'قصف', 'إيران', 'عسكري',
];

// ── Priority accounts (trusted — no keyword filter needed) ──────
const PRIORITY_ACCOUNTS = ['modgovae', 'centcom', 'idf'];

function isConflictRelevant(text) {
  const lower = text.toLowerCase();
  return CONFLICT_KEYWORDS.some(kw => lower.includes(kw));
}

function isPriorityAccount(username) {
  return PRIORITY_ACCOUNTS.some(p => p.toLowerCase() === username.toLowerCase());
}

// ── State ────────────────────────────────────────────────────────

let _streamController = null;  // AbortController for active stream
let _reconnectTimeout = null;
let _reconnectDelay = 1000;    // Start at 1s, exponential backoff
const MAX_RECONNECT_DELAY = 300_000; // Max 5 min

let _tweetCache = [];          // Rolling cache of recent tweets (headline format)
const MAX_CACHE = 100;

let _stats = {
  mode: 'stream',
  connected: false,
  connectedSince: null,
  tweetsReceived: 0,
  tweetsInjected: 0,
  reconnects: 0,
  errors: [],
  rulesActive: 0,
  lastTweet: null,
};

// ── Stream Rules ─────────────────────────────────────────────────

/**
 * Build filter rules for Filtered Stream.
 * Groups accounts into rules (max 512 chars per rule value).
 */
function buildStreamRules() {
  const rules = [];

  // Rule 1: GOV accounts (all tweets — no keyword filter needed)
  const govParts = GOV_ACCOUNTS.map(h => `from:${h}`);
  let govRule = '';
  let govBatch = 1;
  for (const part of govParts) {
    const next = govRule ? `${govRule} OR ${part}` : part;
    if (next.length > 480) {
      rules.push({ value: govRule, tag: `gov-${govBatch}` });
      govRule = part;
      govBatch++;
    } else {
      govRule = next;
    }
  }
  if (govRule) rules.push({ value: govRule, tag: `gov-${govBatch}` });

  // Rule 2: OSINT accounts (all tweets — filter in code)
  const osintParts = OSINT_ACCOUNTS.map(h => `from:${h}`);
  let osintRule = '';
  let osintBatch = 1;
  for (const part of osintParts) {
    const next = osintRule ? `${osintRule} OR ${part}` : part;
    if (next.length > 480) {
      rules.push({ value: osintRule, tag: `osint-${osintBatch}` });
      osintRule = part;
      osintBatch++;
    } else {
      osintRule = next;
    }
  }
  if (osintRule) rules.push({ value: osintRule, tag: `osint-${osintBatch}` });

  return rules;
}

/** Delete all existing stream rules */
async function deleteAllRules() {
  const res = await fetch('https://api.twitter.com/2/tweets/search/stream/rules', {
    headers: { Authorization: `Bearer ${X_BEARER_TOKEN}` },
  });
  const data = await res.json();

  if (data.data && data.data.length > 0) {
    const ids = data.data.map(r => r.id);
    await fetch('https://api.twitter.com/2/tweets/search/stream/rules', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${X_BEARER_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ delete: { ids } }),
    });
    console.log(`[X-STREAM] Deleted ${ids.length} old rules`);
  }
}

/** Set up stream filter rules */
async function setupRules() {
  // Clear old rules first
  await deleteAllRules();

  const rules = buildStreamRules();
  const res = await fetch('https://api.twitter.com/2/tweets/search/stream/rules', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${X_BEARER_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ add: rules }),
  });

  const data = await res.json();
  if (data.errors) {
    console.error('[X-STREAM] Rule errors:', JSON.stringify(data.errors));
    _stats.errors.push({ time: new Date().toISOString(), error: `Rule setup failed: ${JSON.stringify(data.errors).substring(0, 200)}` });
    return false;
  }

  const created = data.meta?.summary?.created || 0;
  _stats.rulesActive = created;
  console.log(`[X-STREAM] ${created} rules active — monitoring ${GOV_ACCOUNTS.length} GOV + ${OSINT_ACCOUNTS.length} OSINT accounts`);
  return true;
}

// ── Tweet processor ──────────────────────────────────────────────

function processTweet(tweetData) {
  try {
    const tweet = tweetData.data;
    if (!tweet) return null;

    // Build author lookup
    const authors = {};
    if (tweetData.includes?.users) {
      for (const u of tweetData.includes.users) {
        authors[u.id] = u.username;
      }
    }

    // Skip retweets
    if (tweet.referenced_tweets?.some(r => r.type === 'retweeted')) return null;

    const username = authors[tweet.author_id] || 'unknown';
    const text = tweet.text || '';

    // Priority accounts (@modgovae, CENTCOM, IDF): forward everything.
    // Other GOV accounts: require conflict relevance (no domestic news).
    // OSINT accounts: always require conflict relevance.
    const isPriority = isPriorityAccount(username);
    const isGov = GOV_ACCOUNTS.some(h => h.toLowerCase() === username.toLowerCase());
    if (!isPriority && !isConflictRelevant(text)) return null;

    const sourceLabel = HANDLE_TO_SOURCE[username.toLowerCase()] || `@${username}`;

    const item = {
      title: text.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim(),
      link: `https://x.com/${username}/status/${tweet.id}`,
      pubDate: tweet.created_at || new Date().toISOString(),
      source: sourceLabel,
    };

    // Add to cache (front = newest)
    _tweetCache.unshift(item);
    if (_tweetCache.length > MAX_CACHE) _tweetCache = _tweetCache.slice(0, MAX_CACHE);

    _stats.tweetsReceived++;
    _stats.tweetsInjected++;
    _stats.lastTweet = {
      source: sourceLabel,
      time: item.pubDate,
      preview: text.substring(0, 80),
    };

    console.log(`[X-STREAM] 🔔 @${username}: ${text.substring(0, 100)}${text.length > 100 ? '...' : ''}`);
    return item;
  } catch (err) {
    console.error(`[X-STREAM] Tweet processing error: ${err.message}`);
    return null;
  }
}

// ── Streaming connection ─────────────────────────────────────────

async function connectStream() {
  if (_streamController) {
    _streamController.abort();
    _streamController = null;
  }

  _streamController = new AbortController();

  const url = 'https://api.twitter.com/2/tweets/search/stream?' +
    'tweet.fields=created_at,author_id,text,referenced_tweets&' +
    'user.fields=username&' +
    'expansions=author_id';

  try {
    console.log('[X-STREAM] Connecting to Filtered Stream...');

    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${X_BEARER_TOKEN}`,
        'User-Agent': 'BRE4CH-XSTREAM/1.0',
      },
      signal: _streamController.signal,
    });

    if (res.status === 429) {
      const reset = res.headers.get('x-rate-limit-reset');
      const waitMs = reset ? (parseInt(reset) * 1000 - Date.now()) : 60_000;
      console.warn(`[X-STREAM] Rate limited — retrying in ${Math.round(waitMs / 1000)}s`);
      _stats.errors.push({ time: new Date().toISOString(), error: 'Rate limited (429)' });
      scheduleReconnect(Math.max(waitMs, 10_000));
      return;
    }

    if (!res.ok) {
      const errBody = await res.text();
      console.error(`[X-STREAM] HTTP ${res.status}: ${errBody.substring(0, 200)}`);
      _stats.errors.push({ time: new Date().toISOString(), error: `HTTP ${res.status}` });
      scheduleReconnect();
      return;
    }

    // Connected!
    _stats.connected = true;
    _stats.connectedSince = new Date().toISOString();
    _reconnectDelay = 1000; // Reset backoff
    console.log('[X-STREAM] ✅ Connected — listening for real-time tweets');

    // Read the NDJSON stream
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        console.log('[X-STREAM] Stream ended');
        break;
      }

      buffer += decoder.decode(value, { stream: true });

      // Process complete JSON lines
      const lines = buffer.split('\n');
      buffer = lines.pop() || ''; // Keep incomplete line in buffer

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue; // Heartbeat (empty line)

        try {
          const data = JSON.parse(trimmed);
          processTweet(data);
        } catch {
          // Not valid JSON — skip (could be partial)
        }
      }
    }
  } catch (err) {
    if (err.name === 'AbortError') {
      console.log('[X-STREAM] Stream aborted (intentional)');
      return; // Don't reconnect if intentionally stopped
    }
    console.error(`[X-STREAM] Stream error: ${err.message}`);
    _stats.errors.push({ time: new Date().toISOString(), error: err.message });
  }

  // Disconnected — reconnect
  _stats.connected = false;
  scheduleReconnect();
}

function scheduleReconnect(delay) {
  const d = delay || _reconnectDelay;
  console.log(`[X-STREAM] Reconnecting in ${Math.round(d / 1000)}s...`);
  _stats.reconnects++;

  clearTimeout(_reconnectTimeout);
  _reconnectTimeout = setTimeout(() => connectStream(), d);

  // Exponential backoff (capped at MAX_RECONNECT_DELAY)
  if (!delay) {
    _reconnectDelay = Math.min(_reconnectDelay * 2, MAX_RECONNECT_DELAY);
  }
}

// ── Fallback: one-shot poll (used for initial seed + manual trigger) ──

async function pollOnce() {
  if (!X_BEARER_TOKEN) return [];

  const allAccounts = [...GOV_ACCOUNTS, ...OSINT_ACCOUNTS];
  const query = allAccounts.map(h => `from:${h}`).join(' OR ');

  // Split if > 512 chars
  const queries = [];
  if (query.length > 512) {
    const mid = Math.ceil(allAccounts.length / 2);
    queries.push(allAccounts.slice(0, mid).map(h => `from:${h}`).join(' OR '));
    queries.push(allAccounts.slice(mid).map(h => `from:${h}`).join(' OR '));
  } else {
    queries.push(query);
  }

  const allTweets = [];
  for (const q of queries) {
    try {
      const params = new URLSearchParams({
        query: q,
        'tweet.fields': 'created_at,author_id,text,referenced_tweets',
        'user.fields': 'username',
        expansions: 'author_id',
        max_results: '20',
      });

      const res = await fetch(`https://api.twitter.com/2/tweets/search/recent?${params}`, {
        headers: { Authorization: `Bearer ${X_BEARER_TOKEN}` },
      });

      if (!res.ok) continue;
      const data = await res.json();
      if (!data.data) continue;

      const authors = {};
      if (data.includes?.users) {
        for (const u of data.includes.users) authors[u.id] = u.username;
      }

      for (const tweet of data.data) {
        if (tweet.referenced_tweets?.some(r => r.type === 'retweeted')) continue;
        const username = authors[tweet.author_id] || 'unknown';
        const text = tweet.text || '';
        const isPriority = isPriorityAccount(username);
        if (!isPriority && !isConflictRelevant(text)) continue;

        const sourceLabel = HANDLE_TO_SOURCE[username.toLowerCase()] || `@${username}`;
        allTweets.push({
          title: text.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim(),
          link: `https://x.com/${username}/status/${tweet.id}`,
          pubDate: tweet.created_at || new Date().toISOString(),
          source: sourceLabel,
        });
      }
    } catch (err) {
      console.error(`[X-STREAM] Poll error: ${err.message}`);
    }
  }

  // Seed the cache
  if (allTweets.length > 0) {
    _tweetCache = [...allTweets, ..._tweetCache].slice(0, MAX_CACHE);
    _stats.tweetsReceived += allTweets.length;
    _stats.tweetsInjected += allTweets.length;
    console.log(`[X-STREAM] Seed poll: ${allTweets.length} tweets cached`);
  }

  return allTweets;
}

// ── Public API ───────────────────────────────────────────────────

export async function startXScraperScheduler() {
  if (!X_BEARER_TOKEN) {
    console.warn('[X-SCRAPER] No X_BEARER_TOKEN configured — X monitoring DISABLED');
    return;
  }

  console.log(`[X-SCRAPER] Mode: ${X_MODE.toUpperCase()}`);
  console.log(`[X-SCRAPER] Monitoring ${GOV_ACCOUNTS.length} GOV + ${OSINT_ACCOUNTS.length} OSINT accounts`);

  if (X_MODE === 'standby') {
    // ── STANDBY MODE (DRP — dormant until PROD fails) ─────────
    _stats.mode = 'standby';
    console.log('[X-STANDBY] Dormant — switch to X_MODE=stream if PROD goes down');
    return;
  }

  if (X_MODE === 'poll') {
    // ── POLL MODE (fallback if stream unavailable) ──────────
    _stats.mode = 'poll';
    const interval = X_POLL_INTERVAL || 300_000; // default 5 min
    console.log(`[X-POLL] Polling every ${interval / 1000}s`);

    // Seed cache immediately
    await pollOnce();

    // Periodic polling
    setInterval(async () => {
      try {
        console.log('[X-POLL] Polling...');
        await pollOnce();
      } catch (err) {
        console.error(`[X-POLL] Error: ${err.message}`);
      }
    }, interval);
    return;
  }

  // ── STREAM MODE (PROD — real-time Filtered Stream) ──────────
  console.log(`[X-STREAM] Starting real-time Filtered Stream`);

  try {
    // 1. Set up filter rules
    const ok = await setupRules();
    if (!ok) {
      console.error('[X-STREAM] Failed to set up rules — falling back to polling');
      await pollOnce();
      return;
    }

    // 2. Seed cache with recent tweets (so app has data immediately)
    await pollOnce();

    // 3. Connect to real-time stream
    setTimeout(() => connectStream(), 2000);
  } catch (err) {
    console.error(`[X-STREAM] Startup error: ${err.message}`);
    _stats.errors.push({ time: new Date().toISOString(), error: err.message });
  }
}

export function stopXScraper() {
  if (_streamController) {
    _streamController.abort();
    _streamController = null;
  }
  clearTimeout(_reconnectTimeout);
  _stats.connected = false;
  console.log('[X-STREAM] Stopped');
}

/** Alias for compatibility with old poll-based code */
export async function pollXAccounts() {
  return pollOnce();
}

export function getXScraperStatus() {
  return {
    enabled: !!X_BEARER_TOKEN,
    ..._stats,
    govAccounts: GOV_ACCOUNTS.length,
    osintAccounts: OSINT_ACCOUNTS.length,
    cachedTweets: _tweetCache.length,
  };
}

/** Returns cached tweets in headline format for injection into sources pipeline */
export function getCachedTweets() {
  return _tweetCache;
}
