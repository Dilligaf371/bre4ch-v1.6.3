// =============================================================================
// BRE4CH — Source Overlay API
// Serves dynamic source metadata (description, sourceLabel, sourceUrl, sourceDate)
// that can be updated without rebuilding the Flutter binary.
//
// GET /api/source-overlay → Current overlay data
// WS  'source_overlay'    → Pushed instantly when sources.json changes on disk
//
// Overlay format (data/sources.json):
// {
//   "version": "2026-03-09",
//   "sources": {
//     "ad-uae-dhafra": {
//       "description": "...",
//       "sourceLabel": "...",
//       "sourceUrl": "...",
//       "sourceDate": "2026-03-09T12:00:00Z"
//     },
//     "ms-tabriz": { ... }
//   }
// }
//
// Keys can be air defense system IDs (ad-*) or missile site IDs (ms-*).
// Only fields present in the overlay are applied; missing fields keep hardcoded values.
// =============================================================================

import { Router } from 'express';
import { readFileSync, watchFile } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { broadcast } from '../services/ws-server.mjs';

const router = Router();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const DATA_PATH = join(__dirname, '..', 'data', 'sources.json');

// ── Read helper ───────────────────────────────────────────────

function loadOverlay() {
  try {
    const raw = readFileSync(DATA_PATH, 'utf-8');
    return JSON.parse(raw);
  } catch (err) {
    console.error('[source-overlay] Failed to read sources:', err.message);
    return null;
  }
}

// ── GET /api/source-overlay (HTTP fallback) ───────────────────

router.get('/source-overlay', (_req, res) => {
  const data = loadOverlay();
  if (data) {
    res.json(data);
  } else {
    res.status(500).json({ error: 'Failed to load source overlay' });
  }
});

// ── File watcher → WS broadcast on change ────────────────────

let _watcherStarted = false;

export function startSourceOverlayWatcher() {
  if (_watcherStarted) return;
  _watcherStarted = true;

  // watchFile polls every 2s — reliable across Linux/macOS
  watchFile(DATA_PATH, { interval: 2000 }, (curr, prev) => {
    if (curr.mtimeMs === prev.mtimeMs) return;

    const data = loadOverlay();
    if (data) {
      broadcast('source_overlay', data);
      console.log(`[source-overlay] File changed → broadcast to clients`);
    }
  });

  console.log('[source-overlay] File watcher active on sources.json');
}

export default router;
