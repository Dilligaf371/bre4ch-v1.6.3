// =============================================================================
// BRE4CH — WATCHDOG-IRAN Briefing Agent
// Generates intelligence briefings at 07:00 and 19:00 UTC using Gemini 2.5 Flash.
// Aggregates RSS + X feeds as context, produces structured Markdown briefing.
//
// Config env vars:
//   GEMINI_API_KEY       — Google AI API key (required)
//   GEMINI_MODEL         — model ID (default gemini-2.5-flash)
//   BRIEFING_GROUNDING   — "true" to enable Google Search (default true)
//
// Schedule: daily at 07:00 UTC and 19:00 UTC
//
// Public API:
//   startBriefingScheduler(getTweets, getHeadlines) — starts cron
//   generateBriefing(tweets, headlines)             — manual trigger
//   getLatestBriefing()                             — returns latest + next time
//   getBriefingStatus()                             — returns agent status
// =============================================================================

import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ── Config ───────────────────────────────────────────────────────

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
const GROUNDING = (process.env.BRIEFING_GROUNDING || 'true') === 'true';
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;
const MISSION_START = new Date('2026-02-28T02:00:00Z');
const SCHEDULE_HOURS = [7, 19]; // UTC hours for briefing generation

// ── Paths ────────────────────────────────────────────────────────

const PROMPT_PATH = join(__dirname, '..', 'data', 'watchdog-prompt.md');
const BRIEFINGS_DIR = join(__dirname, '..', 'data', 'briefings');

try { mkdirSync(BRIEFINGS_DIR, { recursive: true }); } catch { /* exists */ }

// ── State ────────────────────────────────────────────────────────

let _systemPrompt = '';
let _latestBriefing = null;
let _nextBriefingAt = null;
let _stats = {
  totalGenerated: 0,
  lastGeneratedAt: null,
  lastError: null,
  isGenerating: false,
};

// ── Load system prompt ───────────────────────────────────────────

function loadSystemPrompt() {
  try {
    _systemPrompt = readFileSync(PROMPT_PATH, 'utf-8');
    console.log(`[WATCHDOG] System prompt loaded (${_systemPrompt.length} chars)`);
  } catch (err) {
    console.error(`[WATCHDOG] Failed to load system prompt: ${err.message}`);
  }
}

// ── Call Gemini API ──────────────────────────────────────────────

async function callGemini(userPrompt) {
  const body = {
    systemInstruction: { parts: [{ text: _systemPrompt }] },
    contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
    generationConfig: {
      maxOutputTokens: 16384,
      temperature: 0.3,
    },
  };

  // Enable Google Search grounding if configured
  if (GROUNDING) {
    body.tools = [{ googleSearch: {} }];
  }

  const res = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': GEMINI_API_KEY,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API ${res.status}: ${errText.substring(0, 300)}`);
  }

  const data = await res.json();
  const parts = data.candidates?.[0]?.content?.parts || [];
  const text = parts.map(p => p.text || '').join('');

  if (!text) {
    throw new Error('Empty response from Gemini');
  }

  return {
    text,
    usage: data.usageMetadata || {},
    groundingSources: data.candidates?.[0]?.groundingMetadata?.groundingChunks?.length || 0,
  };
}

// ── Generate briefing ────────────────────────────────────────────

export async function generateBriefing(tweetsData = [], headlinesData = []) {
  if (!GEMINI_API_KEY) {
    console.warn('[WATCHDOG] No GEMINI_API_KEY — generation DISABLED');
    return null;
  }

  if (_stats.isGenerating) {
    console.warn('[WATCHDOG] Generation already in progress');
    return null;
  }

  _stats.isGenerating = true;
  const now = new Date();
  const dayN = Math.floor((now.getTime() - MISSION_START.getTime()) / 86400000);
  console.log(`[WATCHDOG] Generating briefing J+${dayN}...`);

  try {
    // Build context from existing feeds
    let userPrompt = `CURRENT DATE: ${now.toISOString()}\nDAY: J+${dayN}\n\n`;

    if (tweetsData.length > 0) {
      userPrompt += `=== LATEST X/TWITTER FEEDS (${tweetsData.length} items) ===\n`;
      for (const t of tweetsData.slice(0, 50)) {
        userPrompt += `[${t.pubDate}] ${t.source}: ${t.title}\nURL: ${t.link}\n\n`;
      }
    }

    if (headlinesData.length > 0) {
      userPrompt += `=== LATEST RSS HEADLINES (${headlinesData.length} items) ===\n`;
      for (const h of headlinesData.slice(0, 50)) {
        userPrompt += `[${h.pubDate}] ${h.source}: ${h.title}\nURL: ${h.link}\n\n`;
      }
    }

    userPrompt += `\nProduis le briefing WATCHDOG-IRAN complet pour ${now.toISOString().split('T')[0]}, jour J+${dayN}. `;
    userPrompt += `Utilise le web search pour compléter avec les toutes dernières informations. `;
    userPrompt += `Suis EXACTEMENT la structure définie dans ton system prompt.`;

    const result = await callGemini(userPrompt);

    // Build briefing object
    const briefing = {
      id: `briefing-${now.toISOString().replace(/[:.]/g, '-')}`,
      content: result.text,
      generatedAt: now.toISOString(),
      dayN,
      tokenUsage: result.usage,
      groundingSources: result.groundingSources,
    };

    // Save to file
    const filename = `briefing-${now.toISOString().split('T')[0]}-${now.getUTCHours().toString().padStart(2, '0')}h.json`;
    writeFileSync(join(BRIEFINGS_DIR, filename), JSON.stringify(briefing, null, 2), 'utf-8');

    // Update state
    _latestBriefing = briefing;
    _nextBriefingAt = getNextScheduledTime().toISOString();
    _stats.totalGenerated++;
    _stats.lastGeneratedAt = now.toISOString();
    _stats.lastError = null;

    const tokens = result.usage.totalTokenCount || '?';
    console.log(`[WATCHDOG] ✅ Briefing generated (${result.text.length} chars, ${tokens} tokens, ${result.groundingSources} grounding sources)`);
    return briefing;
  } catch (err) {
    _stats.lastError = { time: new Date().toISOString(), message: err.message };
    console.error(`[WATCHDOG] ❌ Generation failed: ${err.message}`);
    return null;
  } finally {
    _stats.isGenerating = false;
  }
}

// ── Load latest briefing from disk ───────────────────────────────

function loadLatestBriefing() {
  try {
    const files = readdirSync(BRIEFINGS_DIR)
      .filter(f => f.startsWith('briefing-') && f.endsWith('.json'))
      .sort()
      .reverse();

    if (files.length > 0) {
      const raw = readFileSync(join(BRIEFINGS_DIR, files[0]), 'utf-8');
      _latestBriefing = JSON.parse(raw);
      _nextBriefingAt = getNextScheduledTime().toISOString();
      console.log(`[WATCHDOG] Loaded latest briefing from ${files[0]}`);
    }

    // Prune old briefings (keep last 20)
    const files2 = readdirSync(BRIEFINGS_DIR)
      .filter(f => f.startsWith('briefing-') && f.endsWith('.json'))
      .sort();
    if (files2.length > 20) {
      const toDelete = files2.slice(0, files2.length - 20);
      for (const f of toDelete) {
        try { import('node:fs').then(fs => fs.unlinkSync(join(BRIEFINGS_DIR, f))); } catch { /* ok */ }
      }
      console.log(`[WATCHDOG] Pruned ${toDelete.length} old briefings`);
    }
  } catch (err) {
    console.error(`[WATCHDOG] Failed to load latest briefing: ${err.message}`);
  }
}

// ── Public API ───────────────────────────────────────────────────

export function getLatestBriefing() {
  return {
    briefing: _latestBriefing,
    nextBriefingAt: _nextBriefingAt,
  };
}

export function getBriefingStatus() {
  return {
    enabled: !!GEMINI_API_KEY,
    model: MODEL,
    grounding: GROUNDING,
    schedule: SCHEDULE_HOURS.map(h => `${h.toString().padStart(2, '0')}:00 UTC`),
    nextBriefingAt: _nextBriefingAt,
    latestBriefingId: _latestBriefing?.id || null,
    latestGeneratedAt: _latestBriefing?.generatedAt || null,
    ..._stats,
  };
}

// ── Scheduler helpers ────────────────────────────────────────────

/**
 * Compute the next scheduled briefing time (next 07:00 or 19:00 UTC).
 */
function getNextScheduledTime(from = new Date()) {
  const candidates = [];
  for (const h of SCHEDULE_HOURS) {
    // Today at this hour
    const t = new Date(from);
    t.setUTCHours(h, 0, 0, 0);
    if (t.getTime() > from.getTime()) {
      candidates.push(t);
    }
    // Tomorrow at this hour
    const t2 = new Date(from);
    t2.setUTCDate(t2.getUTCDate() + 1);
    t2.setUTCHours(h, 0, 0, 0);
    candidates.push(t2);
  }
  candidates.sort((a, b) => a.getTime() - b.getTime());
  return candidates[0];
}

/**
 * Schedule the next briefing generation at the next 07:00 or 19:00 UTC.
 */
function scheduleNext(getTweets, getHeadlines) {
  const next = getNextScheduledTime();
  const delayMs = next.getTime() - Date.now();
  _nextBriefingAt = next.toISOString();
  const hhmm = `${next.getUTCHours().toString().padStart(2, '0')}:00`;
  console.log(`[WATCHDOG] Next briefing scheduled at ${next.toISOString()} (${hhmm} UTC, in ${Math.round(delayMs / 60000)}min)`);

  setTimeout(async () => {
    try {
      console.log('[WATCHDOG] Scheduled briefing generation...');
      const tweets = getTweets ? getTweets() : [];
      const headlines = getHeadlines ? getHeadlines() : [];
      await generateBriefing(tweets, headlines);
    } catch (err) {
      console.error(`[WATCHDOG] Scheduled generation error: ${err.message}`);
    }
    // Chain the next one
    scheduleNext(getTweets, getHeadlines);
  }, delayMs);
}

/**
 * Start the briefing scheduler.
 * Generates at 07:00 and 19:00 UTC daily.
 * @param {Function} getTweets   — returns cached X tweets array
 * @param {Function} getHeadlines — returns cached RSS headlines array
 */
export async function startBriefingScheduler(getTweets, getHeadlines) {
  if (!GEMINI_API_KEY) {
    console.warn('[WATCHDOG] No GEMINI_API_KEY configured — Briefing agent DISABLED');
    return;
  }

  loadSystemPrompt();
  loadLatestBriefing();

  console.log(`[WATCHDOG] Briefing agent started — schedule: ${SCHEDULE_HOURS.map(h => h + ':00').join(' & ')} UTC — model: ${MODEL} — grounding: ${GROUNDING}`);

  // Schedule the next fixed-time briefing
  scheduleNext(getTweets, getHeadlines);
}
