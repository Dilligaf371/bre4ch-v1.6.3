import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { config } from 'dotenv';

// Load .env from backend root
config({ path: join(import.meta.dirname, '..', '.env') });

// ─── Ollama / ULTRON ───
export const OLLAMA_URL = process.env.OLLAMA_URL || 'http://localhost:11434';
export const ULTRON_MODEL = process.env.ULTRON_MODEL || 'ultron-34b';
export const PORT = parseInt(process.env.ULTRON_PORT || '3002', 10);

// ─── Liveuamap ───
export const LIVEUAMAP_API_KEY = process.env.LIVEUAMAP_API_KEY || '';

// ─── ULTRON Soul ───
const SOUL_PATH = join(process.env.HOME, '.openclaw', 'agents', 'ultron', 'SOUL.md');
let soul = '';
try {
  soul = readFileSync(SOUL_PATH, 'utf-8');
  console.log('[ULTRON] SOUL.md personality loaded');
} catch {
  console.log('[ULTRON] No SOUL.md found, using built-in personality');
}
export const ULTRON_SOUL = soul;

// ─── Anthropic API Key (C2 agent) ───
const OPENCLAW_PATH = join(process.env.HOME, '.openclaw', 'openclaw.json');
let apiKey = '';
try {
  const parsed = JSON.parse(readFileSync(OPENCLAW_PATH, 'utf-8'));
  apiKey = parsed.env?.ANTHROPIC_API_KEY || '';
  if (apiKey) console.log('[C2] API key loaded from openclaw config');
} catch {
  apiKey = process.env.ANTHROPIC_API_KEY || '';
  if (apiKey) console.log('[C2] API key loaded from environment');
}
if (!apiKey) console.warn('[C2] WARNING: No API key — C2 agent will be offline');
export const ANTHROPIC_API_KEY = apiKey;

// ─── Timers ───
export const SESSION_TTL = 2 * 60 * 60 * 1000;       // 2 hours
export const SESSION_CLEANUP = 10 * 60 * 1000;        // 10 min
export const SOURCE_REFRESH_INTERVAL = 5 * 60 * 1000; // 5 min
export const MAX_HISTORY = 30;

// ─── X (Twitter) API v2 ───
export const X_BEARER_TOKEN = process.env.X_BEARER_TOKEN || '';
export const X_POLL_INTERVAL = parseInt(process.env.X_POLL_INTERVAL || '120000', 10);
