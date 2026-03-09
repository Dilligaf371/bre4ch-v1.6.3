// =============================================================================
// BRE4CH v2 - Push Notification Route
// Scans headlines for high-severity events and sends FCM topic notifications
// =============================================================================

import { Router } from 'express';
import { messaging } from '../firebase.mjs';
import { getCachedHeadlines } from './sources.mjs';

const router = Router();

// ── Keyword Detection (mirrors Flutter emergency_alerts_provider.dart) ──

const EXTREME_KEYWORDS = [
  'nuclear', 'radiological', 'wmd', 'chemical weapon',
  'khamenei killed', 'leader killed', 'capital struck',
  'strait of hormuz closed', 'temple mount',
  'mass casualty', 'nato article 5',
];

const SEVERE_KEYWORDS = [
  'killed', 'strike', 'attack', 'war', 'breaking',
  'missile', 'drone', 'shot down', 'friendly fire',
  'airport shut', 'airport hit', 'warhead',
  'hezbollah', 'retaliation', 'sunk',
];

const MODERATE_KEYWORDS = [
  'iran', 'military', 'bomb', 'explosion',
  'airspace closed', 'intercepted', 'escalation',
  'casualties', 'wounded', 'deployment',
];

function detectSeverity(title) {
  const lower = title.toLowerCase();
  for (const kw of EXTREME_KEYWORDS) if (lower.includes(kw)) return 'extreme';
  for (const kw of SEVERE_KEYWORDS) if (lower.includes(kw)) return 'severe';
  for (const kw of MODERATE_KEYWORDS) if (lower.includes(kw)) return 'moderate';
  return null;
}

function detectRegion(title) {
  const lower = title.toLowerCase();
  if (lower.includes('tehran') || lower.includes('isfahan') || lower.includes('natanz')) return { country: 'iran', city: 'tehran' };
  if (lower.includes('dubai')) return { country: 'uae', city: 'dubai' };
  if (lower.includes('abu dhabi')) return { country: 'uae', city: 'abu_dhabi' };
  if (lower.includes('sharjah')) return { country: 'uae', city: 'sharjah' };
  if (lower.includes('uae') || lower.includes('emirates')) return { country: 'uae', city: null };
  if (lower.includes('tel aviv')) return { country: 'israel', city: 'tel_aviv' };
  if (lower.includes('jerusalem')) return { country: 'israel', city: 'jerusalem' };
  if (lower.includes('haifa')) return { country: 'israel', city: 'haifa' };
  if (lower.includes('israel')) return { country: 'israel', city: null };
  if (lower.includes('riyadh')) return { country: 'ksa', city: 'riyadh' };
  if (lower.includes('jeddah')) return { country: 'ksa', city: 'jeddah' };
  if (lower.includes('saudi') || lower.includes('ksa')) return { country: 'ksa', city: null };
  if (lower.includes('kuwait')) return { country: 'kuwait', city: 'kuwait_city' };
  if (lower.includes('bahrain') || lower.includes('manama')) return { country: 'bahrain', city: 'manama' };
  if (lower.includes('qatar') || lower.includes('doha')) return { country: 'qatar', city: 'doha' };
  if (lower.includes('jordan') || lower.includes('amman')) return { country: 'jordan', city: 'amman' };
  if (lower.includes('oman') || lower.includes('muscat')) return { country: 'oman', city: 'muscat' };
  if (lower.includes('lebanon') || lower.includes('beirut')) return { country: 'lebanon', city: 'beirut' };
  if (lower.includes('strait') || lower.includes('hormuz')) return { country: 'iran', city: null };
  return { country: null, city: null };
}

function detectType(title) {
  const lower = title.toLowerCase();
  if (lower.includes('airport') || lower.includes('airspace') || lower.includes('flight') || lower.includes('notam')) return 'airport';
  if (lower.includes('shelter') || lower.includes('bunker') || lower.includes('evacuate') || lower.includes('civil defense')) return 'shelter';
  if (lower.includes('embassy') || lower.includes('consulate') || lower.includes('diplomatic')) return 'embassy';
  return 'danger';
}

// ── Dedup ────────────────────────────────────────────────────────────

const sentHeadlines = new Set();
const MAX_SENT = 500;

// ── Send to FCM Topics ──────────────────────────────────────────────

async function sendTopicNotification(headline, severity, region, type, source) {
  if (!messaging) return;

  // ── Topic strategy (v1.8.2 fix) ────────────────────────────────
  // Only use breach_all (global) + country/city topics.
  // Severity & type topics were causing cross-contamination:
  //   e.g. subscribing to UAE still received ALL "extreme" alerts
  //   because the device was also on breach_severity_extreme.
  // Severity/type filtering is now client-side only.
  const topics = new Set();
  topics.add('breach_all');
  if (region.country) topics.add(`breach_country_${region.country}`);
  if (region.city) topics.add(`breach_city_${region.city}`);

  const collapseKey = `breach_${Buffer.from(headline).toString('base64url').slice(0, 32)}`;

  for (const topic of topics) {
    try {
      await messaging.send({
        topic,
        notification: {
          title: `[${severity.toUpperCase()}] ${region.country?.toUpperCase() || 'THEATER'}`,
          body: headline.substring(0, 200),
        },
        data: {
          severity,
          country: region.country || '',
          city: region.city || '',
          type,
          source: source || '',
          headline,
          route: type === 'shelter' ? '/civil-safety'
               : type === 'embassy' ? '/embassies'
               : type === 'airport' ? '/airports'
               : '/delta-s',
          timestamp: Date.now().toString(),
        },
        apns: {
          headers: {
            'apns-priority': severity === 'extreme' ? '10' : '5',
            'apns-collapse-id': collapseKey,
          },
          payload: {
            aps: {
              sound: severity === 'extreme' ? 'default' : 'default',
              'mutable-content': 1,
              'content-available': 1,
              ...(severity === 'extreme' ? { 'interruption-level': 'critical' } : {}),
            },
          },
        },
        android: {
          priority: severity === 'extreme' ? 'high' : 'normal',
          collapseKey,
          notification: {
            channelId: 'breach_alerts',
            priority: severity === 'extreme' ? 'max' : 'high',
          },
        },
      });
    } catch (err) {
      if (!err.message?.includes('not found')) {
        console.error(`[FCM] Send error (${topic}): ${err.message}`);
      }
    }
  }
}

// ── Headline Scanner ────────────────────────────────────────────────

let lastScanTimestamp = 0;
let totalSent = 0;

export async function scanAndNotify() {
  if (!messaging) return;

  const headlines = getCachedHeadlines();
  let sent = 0;

  for (const h of headlines) {
    const title = h.title || '';
    if (!title || sentHeadlines.has(title)) continue;

    const severity = detectSeverity(title);
    if (!severity) continue;

    sentHeadlines.add(title);
    if (sentHeadlines.size > MAX_SENT) {
      const oldest = sentHeadlines.values().next().value;
      sentHeadlines.delete(oldest);
    }

    const region = detectRegion(title);
    const type = detectType(title);

    await sendTopicNotification(title, severity, region, type, h.source);
    sent++;
  }

  if (sent > 0) {
    totalSent += sent;
    console.log(`[FCM] Sent ${sent} notifications (total: ${totalSent})`);
  }
  lastScanTimestamp = Date.now();
}

// ── Routes ──────────────────────────────────────────────────────────

// Device token registration
const deviceTokens = new Map();

router.post('/notifications/register', (req, res) => {
  const { token, platform } = req.body;
  if (!token) return res.status(400).json({ error: 'Token required' });
  deviceTokens.set(token, { platform, registered: Date.now() });
  console.log(`[FCM] Device registered: ${platform} (${deviceTokens.size} total)`);
  res.json({ ok: true, registered: deviceTokens.size });
});

// Test notification
router.post('/notifications/test', async (req, res) => {
  if (!messaging) return res.status(503).json({ error: 'Firebase not configured' });
  const { topic, title, body } = req.body;
  try {
    const result = await messaging.send({
      topic: topic || 'breach_severity_extreme',
      notification: {
        title: title || '[TEST] BRE4CH Alert',
        body: body || 'Test push notification from BRE4CH backend',
      },
      data: { route: '/delta-s', type: 'test', timestamp: Date.now().toString() },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: {
          aps: {
            sound: 'default',
            'mutable-content': 1,
            'content-available': 1,
          },
        },
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'breach_alerts',
          priority: 'max',
          sound: 'default',
        },
      },
    });
    res.json({ ok: true, messageId: result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Status
router.get('/notifications/status', (_req, res) => {
  res.json({
    fcmOnline: !!messaging,
    registeredDevices: deviceTokens.size,
    sentTotal: totalSent,
    deduplicatedCount: sentHeadlines.size,
    lastScan: lastScanTimestamp,
  });
});

export default router;
