// =============================================================================
// BRE4CH — Defense Stats API
// Air defense interception statistics for GCC / Coalition systems.
//
// GET  /api/defense/stats   → Current interception tallies per system
// GET  /api/defense/scraper → Scraper status (last run, results)
// POST /api/defense/scrape  → Manual scrape trigger
//
// Stats are loaded from data/defense-stats.json (hot-reloadable).
// Auto-scraper runs every 30 min via defense-scraper.mjs.
// =============================================================================

import { Router } from 'express';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { runDefenseScraper, getScraperStatus } from '../scrapers/defense-scraper.mjs';
import { requireAdmin } from '../middleware/auth.mjs';
import { adminLimiter } from '../middleware/rate-limit.mjs';

const router = Router();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const DATA_PATH = join(__dirname, '..', 'data', 'defense-stats.json');

// ── GET /api/defense/stats — serve current stats ─────────────────

router.get('/defense/stats', (_req, res) => {
  try {
    const raw = readFileSync(DATA_PATH, 'utf-8');
    const data = JSON.parse(raw);
    res.json(data);
  } catch (err) {
    console.error('[defense] Failed to read stats:', err.message);
    res.status(500).json({ error: 'Failed to load defense stats' });
  }
});

// ── GET /api/defense/scraper — scraper status ────────────────────

router.get('/defense/scraper', (_req, res) => {
  res.json(getScraperStatus());
});

// ── POST /api/defense/scrape — manual trigger ────────────────────

router.post('/defense/scrape', requireAdmin, adminLimiter, async (_req, res) => {
  try {
    const result = await runDefenseScraper();
    res.json({ ok: true, ...result });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;
