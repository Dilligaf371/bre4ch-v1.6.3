// =============================================================================
// BRE4CH — Rate Limiter (in-memory, no external deps)
// H-01 FIX: Prevent API abuse on public and admin endpoints.
// =============================================================================

const _windows = new Map(); // ip → { count, resetAt }

/**
 * Creates a rate-limiting middleware.
 * @param {object} opts
 * @param {number} opts.windowMs - Time window in milliseconds (default: 60000)
 * @param {number} opts.max      - Max requests per window (default: 60)
 * @param {string} opts.message  - Error message on limit
 */
export function rateLimit({ windowMs = 60_000, max = 60, message = 'Too many requests' } = {}) {
  // Cleanup stale entries every 5 minutes
  setInterval(() => {
    const now = Date.now();
    for (const [ip, entry] of _windows) {
      if (now > entry.resetAt) _windows.delete(ip);
    }
  }, 5 * 60_000);

  return (req, res, next) => {
    const ip = req.ip || req.connection.remoteAddress || 'unknown';
    const now = Date.now();

    let entry = _windows.get(ip);
    if (!entry || now > entry.resetAt) {
      entry = { count: 0, resetAt: now + windowMs };
      _windows.set(ip, entry);
    }

    entry.count++;

    // Set rate-limit headers
    res.set('X-RateLimit-Limit', String(max));
    res.set('X-RateLimit-Remaining', String(Math.max(0, max - entry.count)));
    res.set('X-RateLimit-Reset', String(Math.ceil(entry.resetAt / 1000)));

    if (entry.count > max) {
      return res.status(429).json({
        error: message,
        retryAfter: Math.ceil((entry.resetAt - now) / 1000),
      });
    }

    next();
  };
}

// Pre-configured limiters
export const apiLimiter = rateLimit({ windowMs: 60_000, max: 120 });       // 120 req/min — normal API
export const adminLimiter = rateLimit({ windowMs: 60_000, max: 10 });       // 10 req/min — admin triggers
export const strictLimiter = rateLimit({ windowMs: 60_000, max: 30 });      // 30 req/min — strict
