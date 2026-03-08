// =============================================================================
// BRE4CH — X Monitor Routes
// GET  /api/x/status     → scraper status
// POST /api/x/poll       → manual poll trigger
// GET  /api/x/tweets     → cached tweets (headline format)
// =============================================================================

import { Router } from 'express';
import { getXScraperStatus, pollXAccounts, getCachedTweets } from '../scrapers/x-scraper.mjs';

const router = Router();

router.get('/x/status', (_req, res) => {
  res.json(getXScraperStatus());
});

router.post('/x/poll', async (_req, res) => {
  try {
    const tweets = await pollXAccounts();
    res.json({ ok: true, tweetsFound: tweets.length, tweets });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

router.get('/x/tweets', (_req, res) => {
  const tweets = getCachedTweets();
  res.json({ items: tweets, count: tweets.length });
});

export default router;
