// =============================================================================
// BRE4CH v2 - Cyber Operations API
// Allied cyber/EW ops + Iranian threat groups
//
// GET /api/cyber        → Full cyber metrics
// GET /api/cyber/allied → Allied ops only
// GET /api/cyber/threats → Iranian threat groups only
// =============================================================================

import { Router } from 'express';

const router = Router();

// ── Allied Cyber / EW Operations ─────────────────────────────────

const alliedOps = [
  {
    label: 'EW Strait of Hormuz',
    value: 1,
    desc: 'Electronic warfare activity confirmed (Fox News)',
  },
  {
    label: 'State Broadcaster',
    value: 1,
    desc: 'Iranian state broadcaster struck and dismantled (IDF)',
  },
];

// ── Iranian Threat Groups ────────────────────────────────────────

const iranianGroups = [
  {
    name: 'CyberAv3ngers',
    target: 'US/GCC water & power SCADA',
    status: 'active',
    severity: 'critical',
  },
  {
    name: 'APT42 (Charming Kitten)',
    target: 'US/IL govt credentials phishing',
    status: 'active',
    severity: 'high',
  },
  {
    name: 'MuddyWater',
    target: 'GCC telecom/energy backdoors',
    status: 'active',
    severity: 'high',
  },
  {
    name: 'Void Manticore (Storm-842)',
    target: 'Israeli infrastructure wiper',
    status: 'active',
    severity: 'critical',
  },
  {
    name: 'Cotton Sandstorm',
    target: 'US social media disinfo ops',
    status: 'active',
    severity: 'high',
  },
];

// ── Endpoints ────────────────────────────────────────────────────

router.get('/cyber', (_req, res) => {
  res.json({
    alliedMeta: { label: 'ALLIED CYBER/EW OPS', color: 'text-green-400' },
    alliedOps,
    iranianMeta: { label: 'IRANIAN CYBER THREATS', color: 'text-red-400' },
    iranianGroups,
    lastRefresh: new Date().toISOString(),
  });
});

router.get('/cyber/allied', (_req, res) => {
  res.json({
    ops: alliedOps,
    count: alliedOps.length,
    lastRefresh: new Date().toISOString(),
  });
});

router.get('/cyber/threats', (_req, res) => {
  res.json({
    groups: iranianGroups,
    count: iranianGroups.length,
    lastRefresh: new Date().toISOString(),
  });
});

export default router;
