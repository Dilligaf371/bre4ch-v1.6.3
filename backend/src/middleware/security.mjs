// =============================================================================
// BRE4CH — Security Headers Middleware
// H-04 FIX: CORS restriction + security headers (replaces helmet).
// No external deps — pure Express middleware.
// =============================================================================

/**
 * Security headers middleware (lightweight helmet replacement).
 */
export function securityHeaders(req, res, next) {
  // Prevent MIME type sniffing
  res.set('X-Content-Type-Options', 'nosniff');

  // Prevent clickjacking
  res.set('X-Frame-Options', 'DENY');

  // XSS protection (legacy browsers)
  res.set('X-XSS-Protection', '1; mode=block');

  // Strict Transport Security (1 year)
  res.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');

  // Don't leak referrer
  res.set('Referrer-Policy', 'no-referrer');

  // Content Security Policy (API only — no HTML rendering)
  res.set('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");

  // Prevent caching of sensitive responses
  if (req.path.includes('/forces') || req.path.includes('/cyber') || req.path.includes('/c2')) {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.set('Pragma', 'no-cache');
  }

  next();
}

/**
 * Restrictive CORS middleware.
 * Only allows known origins (the app + admin tools).
 */
export function restrictiveCors(req, res, next) {
  const allowedOrigins = [
    'https://api.bre4ch.com',
    'https://bre4ch.com',
    'capacitor://localhost',   // iOS app
    'http://localhost',        // dev
    'http://localhost:3002',   // dev backend
  ];

  const origin = req.headers.origin;

  if (origin && allowedOrigins.includes(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
  }

  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Max-Age', '86400'); // 24h preflight cache

  // Handle preflight
  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }

  next();
}
