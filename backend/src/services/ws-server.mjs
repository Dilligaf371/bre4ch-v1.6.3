// =============================================================================
// BRE4CH — WebSocket Server
// Persistent WS connections for real-time data push to Flutter clients.
// Protocol matches BreachSocketService (Flutter) expectations.
//
// Server → Client : { "type": "<channel>", "data": { ... } }
// Server → Client : { "type": "ping" }
// Client → Server : { "type": "auth", "token": "..." }
// Client → Server : { "type": "pong" }
// =============================================================================

import { WebSocketServer } from 'ws';

const HEARTBEAT_INTERVAL = 30_000; // 30s ping
const AUTH_TIMEOUT = 10_000;       // 10s to authenticate

// ── Client tracking ──────────────────────────────────────────────

const _clients = new Set();
let _wss = null;

// ── Start ────────────────────────────────────────────────────────

/**
 * Attach WebSocket server to an existing HTTP server.
 * @param {import('node:http').Server} httpServer
 */
export function startWsServer(httpServer) {
  _wss = new WebSocketServer({ server: httpServer, path: '/ws' });

  _wss.on('connection', (ws) => {
    ws.isAlive = true;
    ws.isAuthed = false;

    // Auth timeout — disconnect if no auth within 10s
    const authTimer = setTimeout(() => {
      if (!ws.isAuthed) {
        ws.close(4001, 'Auth timeout');
      }
    }, AUTH_TIMEOUT);

    ws.on('message', (raw) => {
      try {
        const msg = JSON.parse(raw.toString());

        if (msg.type === 'auth') {
          // Accept any auth for now (token validation can be added later)
          ws.isAuthed = true;
          clearTimeout(authTimer);
          _clients.add(ws);
          console.log(`[WS] Client authenticated (${_clients.size} connected)`);
          return;
        }

        if (msg.type === 'pong') {
          ws.isAlive = true;
          return;
        }
      } catch {
        // Ignore malformed messages
      }
    });

    ws.on('close', () => {
      clearTimeout(authTimer);
      _clients.delete(ws);
    });

    ws.on('error', () => {
      clearTimeout(authTimer);
      _clients.delete(ws);
    });
  });

  // ── Heartbeat — ping every 30s, drop dead clients ──────────────

  setInterval(() => {
    for (const ws of _clients) {
      if (!ws.isAlive) {
        _clients.delete(ws);
        ws.terminate();
        continue;
      }
      ws.isAlive = false;
      try {
        ws.send(JSON.stringify({ type: 'ping' }));
      } catch {
        _clients.delete(ws);
      }
    }
  }, HEARTBEAT_INTERVAL);

  console.log(`[WS] Server started on /ws (heartbeat: ${HEARTBEAT_INTERVAL / 1000}s)`);
}

// ── Broadcast ────────────────────────────────────────────────────

/**
 * Push a typed message to all authenticated clients.
 * @param {string} type   — message type ('stats', 'event', 'headlines', etc.)
 * @param {object} data   — payload
 */
export function broadcast(type, data) {
  if (_clients.size === 0) return;

  const msg = JSON.stringify({ type, data });
  let sent = 0;

  for (const ws of _clients) {
    try {
      if (ws.readyState === ws.OPEN) {
        ws.send(msg);
        sent++;
      }
    } catch {
      _clients.delete(ws);
    }
  }

  if (sent > 0) {
    console.log(`[WS] Broadcast '${type}' to ${sent} client(s)`);
  }
}

/**
 * Get current connection count.
 */
export function getWsClientCount() {
  return _clients.size;
}
