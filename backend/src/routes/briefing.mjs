// =============================================================================
// BRE4CH — WATCHDOG-IRAN Briefing Routes
// GET  /api/briefing/latest   → latest briefing + next briefing time
// GET  /api/briefing/status   → agent status (model, interval, stats)
// POST /api/briefing/generate → manual trigger (admin)
// =============================================================================

import { Router } from 'express';
import {
  getLatestBriefing,
  getBriefingStatus,
  generateBriefing,
} from '../services/briefing-agent.mjs';
import { requireAdmin } from '../middleware/auth.mjs';
import { adminLimiter } from '../middleware/rate-limit.mjs';

const router = Router();

// ── GET /api/briefing/latest — serve latest briefing ─────────────

router.get('/briefing/latest', (_req, res) => {
  const data = getLatestBriefing();
  if (!data.briefing) {
    return res.status(404).json({
      error: 'No briefing available yet',
      nextBriefingAt: data.nextBriefingAt,
    });
  }
  res.json(data);
});

// ── GET /api/briefing/status — agent status ──────────────────────

router.get('/briefing/status', (_req, res) => {
  res.json(getBriefingStatus());
});

// ── POST /api/briefing/generate — manual trigger ─────────────────

router.post('/briefing/generate', requireAdmin, adminLimiter, async (_req, res) => {
  try {
    const result = await generateBriefing();
    if (!result) {
      return res.status(503).json({ ok: false, error: 'Generation unavailable or already in progress' });
    }
    res.json({ ok: true, briefingId: result.id, generatedAt: result.generatedAt });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;
