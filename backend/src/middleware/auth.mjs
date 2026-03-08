// =============================================================================
// BRE4CH — Auth Middleware
// CRIT-02 FIX: Bearer token verification on protected routes.
// =============================================================================

import { createHmac } from 'node:crypto';

// API key loaded from .env (set in server.mjs)
let _apiKey = '';

/**
 * Initialize the auth middleware with the API key.
 * @param {string} key - The Bearer API key from .env
 */
export function initAuth(key) {
  _apiKey = key || '';
  if (!_apiKey) {
    console.warn('[AUTH] WARNING: No API_KEY configured — auth middleware disabled');
  }
}

/**
 * Middleware that verifies Bearer token on protected routes.
 * If no API key is configured, requests pass through (graceful degradation).
 */
export function requireAuth(req, res, next) {
  // If no key configured, skip auth (dev mode / graceful degradation)
  if (!_apiKey) return next();

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.slice(7);

  // Constant-time comparison to prevent timing attacks
  if (!timingSafeEqual(token, _apiKey)) {
    return res.status(403).json({ error: 'Invalid API key' });
  }

  next();
}

/**
 * Middleware for admin-only routes (POST triggers like scrape, generate).
 * Same as requireAuth but logs the action.
 */
export function requireAdmin(req, res, next) {
  // If no key configured, skip auth (dev mode)
  if (!_apiKey) return next();

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Admin authentication required' });
  }

  const token = authHeader.slice(7);

  if (!timingSafeEqual(token, _apiKey)) {
    return res.status(403).json({ error: 'Invalid admin credentials' });
  }

  console.log(`[AUTH] Admin action: ${req.method} ${req.path} from ${req.ip}`);
  next();
}

/**
 * Constant-time string comparison to prevent timing attacks.
 */
function timingSafeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length !== b.length) {
    // Hash both to maintain constant time even on length mismatch
    const ha = createHmac('sha256', 'salt').update(a).digest('hex');
    const hb = createHmac('sha256', 'salt').update(b).digest('hex');
    let diff = 0;
    for (let i = 0; i < ha.length; i++) {
      diff |= ha.charCodeAt(i) ^ hb.charCodeAt(i);
    }
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}
