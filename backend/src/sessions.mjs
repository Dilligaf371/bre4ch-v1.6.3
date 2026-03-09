import { SESSION_TTL, SESSION_CLEANUP } from './config.mjs';

// ─── Session manager — reusable for ULTRON and C2 ───
export function createSessionStore(label) {
  const store = new Map();

  // Auto-cleanup stale sessions
  setInterval(() => {
    const cutoff = Date.now() - SESSION_TTL;
    for (const [key, session] of store) {
      if (session.lastAccess < cutoff) {
        store.delete(key);
        console.log(`[${label}] Cleaned up stale session: ${key}`);
      }
    }
  }, SESSION_CLEANUP);

  return {
    get(id) {
      if (!store.has(id)) {
        store.set(id, { messages: [], lastAccess: Date.now() });
      }
      const session = store.get(id);
      session.lastAccess = Date.now();
      return session;
    },
    get size() {
      return store.size;
    },
  };
}
