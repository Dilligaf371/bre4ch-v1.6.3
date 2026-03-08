import express from 'express';
import { PORT, OLLAMA_URL, ULTRON_MODEL, ULTRON_SOUL, ANTHROPIC_API_KEY, LIVEUAMAP_API_KEY } from './config.mjs';
import ultronRouter, { ultronSessions } from './routes/ultron.mjs';
import c2Router, { c2Sessions } from './routes/c2.mjs';
import sourcesRouter, { startRefreshScheduler } from './routes/sources.mjs';
import centcomRouter from './routes/centcom.mjs';
import airportsRouter from './routes/airports.mjs';
import forcesRouter from './routes/forces.mjs';
import cyberRouter from './routes/cyber.mjs';
import statsRouter from './routes/stats.mjs';
import defenseRouter from './routes/defense.mjs';
import { startDefenseScraperScheduler } from './scrapers/defense-scraper.mjs';
import notificationsRouter, { scanAndNotify } from './routes/notifications.mjs';
import xMonitorRouter from "./routes/x-monitor.mjs";
import briefingRouter from "./routes/briefing.mjs";
import { startBriefingScheduler } from "./services/briefing-agent.mjs";
import { startXScraperScheduler } from './scrapers/x-scraper.mjs';

// ─── Security middleware (v1.8.2) ───
import { initAuth } from './middleware/auth.mjs';
import { apiLimiter } from './middleware/rate-limit.mjs';
import { securityHeaders, restrictiveCors } from './middleware/security.mjs';

const app = express();

// ─── H-04: Security headers on all responses ───
app.use(securityHeaders);

// ─── H-04: Restrictive CORS (replaces open cors()) ───
app.use(restrictiveCors);

app.use(express.json());

// ─── H-01: Global rate limiting (120 req/min per IP) ───
app.use('/api', apiLimiter);

// ─── CRIT-02: Init admin auth (from .env ADMIN_API_KEY) ───
initAuth(process.env.ADMIN_API_KEY || '');

// ─── Mount routes ───
app.use('/api', ultronRouter);
app.use('/api', c2Router);
app.use('/api', sourcesRouter);
app.use('/api', centcomRouter);
app.use('/api', airportsRouter);
app.use('/api', forcesRouter);
app.use('/api', cyberRouter);
app.use('/api', statsRouter);
app.use('/api', defenseRouter);
app.use('/api', xMonitorRouter);
app.use('/api', notificationsRouter);
app.use('/api', briefingRouter);

// ─── Privacy Policy & Support ───
app.get('/privacy', (_req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>BRE4CH — Privacy Policy</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0f0f14;color:#c8c8d0;line-height:1.7;padding:40px 20px}
.container{max-width:720px;margin:0 auto}
h1{color:#dcb43c;font-size:28px;margin-bottom:8px}
h2{color:#e0e0e0;font-size:18px;margin:28px 0 10px;border-bottom:1px solid #2a2a35;padding-bottom:6px}
p,li{font-size:15px;margin-bottom:10px}
ul{padding-left:20px}
.subtitle{color:#888;font-size:14px;margin-bottom:32px}
a{color:#dcb43c}
.footer{margin-top:40px;padding-top:20px;border-top:1px solid #2a2a35;color:#666;font-size:13px}
</style>
</head>
<body>
<div class="container">
<h1>BRE4CH — Privacy Policy</h1>
<p class="subtitle">Last updated: March 4, 2026</p>

<h2>1. Overview</h2>
<p>BRE4CH ("the App") is an OSINT crisis intelligence platform. We are committed to protecting your privacy. This policy explains what data we collect and how we use it.</p>

<h2>2. Data We Collect</h2>
<p><strong>We do not collect any personal data.</strong> The App does not require account creation, login, or registration. Specifically:</p>
<ul>
<li>No names, email addresses, or phone numbers are collected</li>
<li>No location data is collected or tracked</li>
<li>No analytics or tracking SDKs are included</li>
<li>No cookies are used</li>
<li>No advertising identifiers are collected</li>
</ul>

<h2>3. Data Sources</h2>
<p>The App aggregates publicly available information from open sources (OSINT) including news agencies, government press offices, and public databases. No user-generated content is collected or stored.</p>

<h2>4. Network Requests</h2>
<p>The App communicates with our backend server to retrieve aggregated intelligence feeds. These requests do not transmit any personally identifiable information. No IP addresses are logged or stored.</p>

<h2>5. Third-Party Services</h2>
<p>The App may link to external services (news websites, FlightRadar24, embassy websites). These third-party sites have their own privacy policies. We are not responsible for their data practices.</p>

<h2>6. Data Storage</h2>
<p>No user data is stored on our servers. The App stores minimal local preferences (theme, last viewed tab) on your device only. This data never leaves your device.</p>

<h2>7. Encryption</h2>
<p>All communications between the App and our servers are encrypted using TLS/SSL (HTTPS).</p>

<h2>8. Children's Privacy</h2>
<p>The App is not intended for children under 12. We do not knowingly collect data from children.</p>

<h2>9. Changes to This Policy</h2>
<p>We may update this policy from time to time. Changes will be reflected on this page with an updated date.</p>

<h2>10. Contact</h2>
<p>For questions about this privacy policy, contact us at: <a href="mailto:dev.app.cst@gmail.com">dev.app.cst@gmail.com</a></p>

<div class="footer">&copy; 2026 BRE4CH — OSINT Crisis Intelligence Platform. All rights reserved.</div>
</div>
</body>
</html>`);
});

app.get('/support', (_req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>BRE4CH — Support</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0f0f14;color:#c8c8d0;line-height:1.7;padding:40px 20px}
.container{max-width:720px;margin:0 auto}
h1{color:#dcb43c;font-size:28px;margin-bottom:8px}
h2{color:#e0e0e0;font-size:18px;margin:28px 0 10px}
p{font-size:15px;margin-bottom:10px}
.subtitle{color:#888;font-size:14px;margin-bottom:32px}
a{color:#dcb43c}
.card{background:#1a1a24;border:1px solid #2a2a35;border-radius:10px;padding:24px;margin:16px 0}
.footer{margin-top:40px;padding-top:20px;border-top:1px solid #2a2a35;color:#666;font-size:13px}
</style>
</head>
<body>
<div class="container">
<h1>BRE4CH — Support</h1>
<p class="subtitle">OSINT Crisis Intelligence Platform</p>

<div class="card">
<h2>Contact Support</h2>
<p>For bug reports, feature requests, or general inquiries:</p>
<p>📧 <a href="mailto:dev.app.cst@gmail.com">dev.app.cst@gmail.com</a></p>
</div>

<div class="card">
<h2>FAQ</h2>
<p><strong>Q: Do I need an account?</strong><br>No. BRE4CH works instantly with no registration required.</p>
<p><strong>Q: How often is data updated?</strong><br>Intelligence feeds are refreshed every 1-5 minutes depending on the source.</p>
<p><strong>Q: Is my data collected?</strong><br>No. See our <a href="/privacy">Privacy Policy</a>.</p>
</div>

<div class="footer">&copy; 2026 BRE4CH — All rights reserved.</div>
</div>
</body>
</html>`);
});

// ─── Health check ───
app.get('/api/health', async (_req, res) => {
  let ollamaOnline = false;
  try {
    const r = await fetch(`${OLLAMA_URL}/api/tags`);
    if (r.ok) {
      const data = await r.json();
      ollamaOnline = data.models?.some(m => m.name.startsWith(ULTRON_MODEL)) ?? false;
    }
  } catch { /* Ollama not reachable */ }

  res.json({
    status: ollamaOnline ? 'online' : 'degraded',
    agent: 'ULTRON',
    model: ULTRON_MODEL,
    ollama: ollamaOnline,
    soulLoaded: !!ULTRON_SOUL,
    c2Online: !!ANTHROPIC_API_KEY,
    liveuamapOnline: !!LIVEUAMAP_API_KEY,
    activeSessions: ultronSessions.size + c2Sessions.size,
  });
});

// ─── Start ───
app.listen(PORT, () => {
  console.log(`\n[BRE4CH] Backend v2.1 running on http://localhost:${PORT}`);
  console.log(`[SECURITY] Headers: active | CORS: restrictive | Rate limit: 120/min`);
  console.log(`[AUTH] Admin POST routes: ${process.env.ADMIN_API_KEY ? 'protected' : 'OPEN (no key)'}`);
  console.log(`[ULTRON] Model: ${ULTRON_MODEL} via ${OLLAMA_URL}`);
  console.log(`[ULTRON] SOUL: ${ULTRON_SOUL ? 'loaded' : 'built-in fallback'}`);
  console.log(`[C2]     Claude: ${ANTHROPIC_API_KEY ? 'online' : 'OFFLINE'}`);
  console.log(`[LUAMAP] ${LIVEUAMAP_API_KEY ? 'online' : 'no key'}\n`);
  startRefreshScheduler();
  startDefenseScraperScheduler();
  startXScraperScheduler();
  startBriefingScheduler();

  // Scan headlines for push notifications every 60s
  setInterval(() => scanAndNotify(), 60_000);
  setTimeout(() => scanAndNotify(), 15_000); // First scan 15s after boot
});
