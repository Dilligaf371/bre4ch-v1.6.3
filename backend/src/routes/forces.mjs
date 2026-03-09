// =============================================================================
// BRE4CH v2 - Forces API
// Axis of Resistance + Coalition force feeds
//
// GET /api/forces/axis       → Axis (Iran-led) feeds
// GET /api/forces/coalition  → Coalition (US-led) feeds
// GET /api/forces/all        → Both sides
// =============================================================================

import { Router } from 'express';
import { readFileSync, watchFile } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { broadcast } from '../services/ws-server.mjs';

const router = Router();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const WAR_STATE_PATH = join(__dirname, '..', 'data', 'war-state.json');

// ── Axis of Resistance (Iran-Led) ────────────────────────────────

const axisFeeds = [
  {
    id: 'iran',
    name: 'IRAN (IRGC/ARTESH)',
    flag: '🇮🇷',
    color: 'text-red-400',
    borderColor: 'border-red-500/30',
    bgColor: 'from-red-500/10',
    offensive: [
      { label: 'BM LAUNCHED', value: 482, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'ASCM FIRED', value: 38, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
      { label: 'SHAHEED UAS', value: 967, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'HORMUZ MINING OP', value: 'ACTIVE', color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'BM AT USS LINCOLN', value: '4 [CLAIMED]', color: 'text-red-400', bgColor: 'bg-red-500/20' },
    ],
    defensive: [
      { label: 'KIA [RED CRESCENT]', value: '555+', color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'IADS SITES DESTROYED', value: 14, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
      { label: 'NAVAL VESSELS LOST', value: 9, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'PROVINCES UNDER STRIKE', value: '24/31', color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'NUCLEAR SITES TGT', value: 'NATANZ/FORDOW', color: 'text-red-400', bgColor: 'bg-red-500/20' },
    ],
    source: 'IRGC/IRNA [D4] — Cross-ref Reuters/CENTCOM',
  },
  {
    id: 'hezbollah',
    name: 'HEZBOLLAH',
    flag: '🇱🇧',
    color: 'text-orange-400',
    borderColor: 'border-orange-500/30',
    bgColor: 'from-orange-500/10',
    offensive: [
      { label: 'ROCKET SALVOS (N. ISR)', value: '340+', color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'KORNET ATGM', value: 15, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
      { label: 'UAS LAUNCHED', value: 28, color: 'text-red-400', bgColor: 'bg-red-500/20' },
    ],
    defensive: [
      { label: 'IDF STRIKES (BEIRUT)', value: 'ONGOING', color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'LEADERSHIP TGT', value: 'CONFIRMED', color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'C2 NODES HIT', value: 12, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    source: 'Al Jazeera / IDF [B3]',
  },
  {
    id: 'houthis',
    name: 'HOUTHIS (ANSAR ALLAH)',
    flag: '🇾🇪',
    color: 'text-yellow-400',
    borderColor: 'border-yellow-500/30',
    bgColor: 'from-yellow-500/10',
    offensive: [
      { label: 'ASCM (RED SEA)', value: 12, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'BM AT GCC', value: 8, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
      { label: 'SHAHEED UAS', value: 23, color: 'text-red-400', bgColor: 'bg-red-500/20' },
    ],
    defensive: [
      { label: 'COALITION CAS (HUDAYDAH)', value: 'ONGOING', color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'LAUNCH SITES BDA', value: 6, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    source: 'CENTCOM / Reuters [A2]',
  },
  {
    id: 'pmf',
    name: 'PMF / HASHD (IRAQ)',
    flag: '🇮🇶',
    color: 'text-amber-400',
    borderColor: 'border-amber-500/30',
    bgColor: 'from-amber-500/10',
    offensive: [
      { label: 'ROCKET ATK (US FOB)', value: 14, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'ONE-WAY UAS', value: 8, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'TGT: AIN AL-ASAD', value: 'CONFIRMED', color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    defensive: [
      { label: 'US PRECISION STRIKE', value: 'LAUNCH SITES', color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    source: 'CENTCOM [A2]',
  },
  {
    id: 'russia',
    name: 'RUSSIA',
    flag: '🇷🇺',
    color: 'text-gray-400',
    borderColor: 'border-gray-500/30',
    bgColor: 'from-gray-500/10',
    offensive: [
      { label: 'UNSC VETO', value: 'EXERCISED', color: 'text-gray-400', bgColor: 'bg-gray-500/20' },
      { label: 'INTEL SHARING [SUSP]', value: 'UNCONFIRMED', color: 'text-yellow-400', bgColor: 'bg-yellow-500/20' },
    ],
    defensive: [
      { label: 'DIPLOMATIC MEDIATION', value: 'ACTIVE', color: 'text-gray-400', bgColor: 'bg-gray-500/20' },
    ],
    source: 'Reuters [B3] — DIPLOMATIC SUPPORT',
  },
  {
    id: 'china',
    name: 'CHINA',
    flag: '🇨🇳',
    color: 'text-gray-400',
    borderColor: 'border-gray-500/30',
    bgColor: 'from-gray-500/10',
    offensive: [
      { label: 'UNSC VETO', value: 'EXERCISED', color: 'text-gray-400', bgColor: 'bg-gray-500/20' },
      { label: 'ECONOMIC PRESSURE', value: 'SANCTIONS BLOCK', color: 'text-yellow-400', bgColor: 'bg-yellow-500/20' },
    ],
    defensive: [
      { label: 'DIPLOMATIC STANCE', value: 'CEASEFIRE CALL', color: 'text-gray-400', bgColor: 'bg-gray-500/20' },
    ],
    source: 'Reuters [B3] — DIPLOMATIC SUPPORT',
  },
];

// ── Coalition (US-Led) ───────────────────────────────────────────

const coalitionFeeds = [
  {
    id: 'usa',
    name: 'USA (CENTCOM)',
    flag: '🇺🇸',
    color: 'text-blue-400',
    borderColor: 'border-blue-500/30',
    bgColor: 'from-blue-500/10',
    offensive: [
      { label: 'TGT DESTROYED [BDA]', value: '1,000+', color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
      { label: 'OCA/SEAD SORTIES', value: 247, color: 'text-blue-400', bgColor: 'bg-blue-500/20' },
      { label: 'TLAM SALVOS', value: 312, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
      { label: 'IRGCN VESSELS SUNK', value: 9, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'BANDAR ABBAS NHQ', value: 'DESTROYED', color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'ENEMY KIA [EST]', value: '555+', color: 'text-red-400', bgColor: 'bg-red-500/20' },
    ],
    defensive: [
      { label: 'AEGIS BMD INTERCEPT', value: 23, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'C-RAM ACTIVATIONS', value: 47, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'KIA', value: 6, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'WIA', value: 34, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    source: 'CENTCOM / Reuters [A2]',
  },
  {
    id: 'israel',
    name: 'ISRAEL (IDF/IAF)',
    flag: '🇮🇱',
    color: 'text-cyan-400',
    borderColor: 'border-cyan-500/30',
    bgColor: 'from-cyan-500/10',
    offensive: [
      { label: 'PGM DELIVERED', value: '1,200+', color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
      { label: 'IAF OCA SORTIES', value: '30+', color: 'text-blue-400', bgColor: 'bg-blue-500/20' },
      { label: 'PROVINCES STRUCK', value: '24/31', color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'HVT NEUTRALIZED', value: 7, color: 'text-red-400', bgColor: 'bg-red-500/20' },
    ],
    defensive: [
      { label: 'ARROW-3 BMD', value: 89, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'IRON DOME INTERCEPT', value: 312, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'KIA', value: 9, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'WIA', value: 121, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    source: 'IDF [B2]',
  },
  {
    id: 'uk',
    name: 'UNITED KINGDOM',
    flag: '🇬🇧',
    color: 'text-indigo-400',
    borderColor: 'border-indigo-500/30',
    bgColor: 'from-indigo-500/10',
    offensive: [
      { label: 'RAF TYPHOON SORTIES', value: 48, color: 'text-blue-400', bgColor: 'bg-blue-500/20' },
      { label: 'STORM SHADOW CRUISE', value: 24, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
      { label: 'HARPOON NAVAL STRIKE', value: 6, color: 'text-red-400', bgColor: 'bg-red-500/20' },
    ],
    defensive: [
      { label: 'TYPE 45 SEA VIPER', value: 12, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'PHALANX C-UAS', value: 8, color: 'text-green-400', bgColor: 'bg-green-500/20' },
    ],
    source: 'UK MoD [B2]',
  },
  {
    id: 'uae',
    name: 'UAE',
    flag: '🇦🇪',
    color: 'text-red-400',
    borderColor: 'border-red-500/30',
    bgColor: 'from-red-500/10',
    offensive: [
      { label: 'F-16E BLK60 ISR', value: 12, color: 'text-blue-400', bgColor: 'bg-blue-500/20' },
      { label: 'EW SUPPORT OPS', value: 3, color: 'text-purple-400', bgColor: 'bg-purple-500/20' },
    ],
    defensive: [
      { label: 'THAAD INTERCEPT', value: 97, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'PATRIOT PAC-3 [BM]', value: 165, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'C-UAS INTERCEPT', value: 541, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'UAS PENETRATIONS', value: 21, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'KIA', value: 3, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'WIA', value: 58, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    source: 'UAE MoD / Al Jazeera [A2]',
  },
  {
    id: 'ksa',
    name: 'KSA',
    flag: '🇸🇦',
    color: 'text-emerald-400',
    borderColor: 'border-emerald-500/30',
    bgColor: 'from-emerald-500/10',
    offensive: [
      { label: 'PSAB LOG SUPPORT', value: 'ACTIVE', color: 'text-blue-400', bgColor: 'bg-blue-500/20' },
      { label: 'AAR SORTIES', value: 36, color: 'text-blue-400', bgColor: 'bg-blue-500/20' },
    ],
    defensive: [
      { label: 'PATRIOT/THAAD STATUS', value: 'HIGH ALERT', color: 'text-yellow-400', bgColor: 'bg-yellow-500/20' },
      { label: 'CONFIRMED ATTACKS', value: 'NIL', color: 'text-gray-400', bgColor: 'bg-white/5' },
    ],
    source: 'NO VERIFIED SOURCE [D5]',
  },
  {
    id: 'kuwait',
    name: 'KUWAIT',
    flag: '🇰🇼',
    color: 'text-green-400',
    borderColor: 'border-green-500/30',
    bgColor: 'from-green-500/10',
    offensive: [
      { label: 'ALI AL SALEM HNS', value: 'ACTIVE', color: 'text-blue-400', bgColor: 'bg-blue-500/20' },
    ],
    defensive: [
      { label: 'PATRIOT BMD', value: 97, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'C-UAS INTERCEPT', value: 283, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'KIA', value: 1, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'WIA', value: 32, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    source: 'Kuwait govt / Al Jazeera [A2]',
  },
  {
    id: 'bahrain',
    name: 'BAHRAIN',
    flag: '🇧🇭',
    color: 'text-yellow-400',
    borderColor: 'border-yellow-500/30',
    bgColor: 'from-yellow-500/10',
    offensive: [
      { label: 'NSA BAHRAIN 5TH FLT', value: 'LOG SUPPORT', color: 'text-blue-400', bgColor: 'bg-blue-500/20' },
    ],
    defensive: [
      { label: 'IAMD INTERCEPT', value: 45, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'C-UAS', value: 9, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'KIA', value: 1, color: 'text-red-400', bgColor: 'bg-red-500/20' },
      { label: 'WIA', value: 4, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    source: 'Al Jazeera [B2]',
  },
  {
    id: 'qatar',
    name: 'QATAR',
    flag: '🇶🇦',
    color: 'text-purple-400',
    borderColor: 'border-purple-500/30',
    bgColor: 'from-purple-500/10',
    offensive: [
      { label: 'AL UDEID CAOC', value: 'ACTIVE', color: 'text-blue-400', bgColor: 'bg-blue-500/20' },
      { label: 'E-3 AWACS SUPPORT', value: 'ACTIVE', color: 'text-purple-400', bgColor: 'bg-purple-500/20' },
    ],
    defensive: [
      { label: 'IAMD INTERCEPT', value: 65, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'C-UAS', value: 12, color: 'text-green-400', bgColor: 'bg-green-500/20' },
      { label: 'WIA', value: 16, color: 'text-orange-400', bgColor: 'bg-orange-500/20' },
    ],
    source: 'Al Jazeera [B2]',
  },
];

// ── Endpoints ────────────────────────────────────────────────────

router.get('/forces/axis', (_req, res) => {
  res.json({
    feeds: axisFeeds,
    count: axisFeeds.length,
    side: 'axis',
    lastRefresh: new Date().toISOString(),
  });
});

router.get('/forces/coalition', (_req, res) => {
  res.json({
    feeds: coalitionFeeds,
    count: coalitionFeeds.length,
    side: 'coalition',
    lastRefresh: new Date().toISOString(),
  });
});

router.get('/forces/all', (_req, res) => {
  res.json({
    axis: { feeds: axisFeeds, count: axisFeeds.length },
    coalition: { feeds: coalitionFeeds, count: coalitionFeeds.length },
    lastRefresh: new Date().toISOString(),
  });
});

// ── War State overlay (editable JSON → instant WS push) ───────────

function loadWarState() {
  try {
    const raw = readFileSync(WAR_STATE_PATH, 'utf-8');
    return JSON.parse(raw);
  } catch (err) {
    console.error('[war-state] Failed to read war-state.json:', err.message);
    return null;
  }
}

router.get('/war-state', (_req, res) => {
  const data = loadWarState();
  if (data) {
    res.json(data);
  } else {
    res.status(500).json({ error: 'Failed to load war state overlay' });
  }
});

// ── File watcher → WS broadcast on change ────────────────────

let _warStateWatcherStarted = false;

export function startWarStateWatcher() {
  if (_warStateWatcherStarted) return;
  _warStateWatcherStarted = true;

  watchFile(WAR_STATE_PATH, { interval: 2000 }, (curr, prev) => {
    if (curr.mtimeMs === prev.mtimeMs) return;

    const data = loadWarState();
    if (data) {
      broadcast('war_state', data);
      console.log(`[war-state] File changed → broadcast to clients`);
    }
  });

  console.log('[war-state] File watcher active on war-state.json');
}

export default router;
