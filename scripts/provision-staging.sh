#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# BRE4CH — Staging Server Provisioning Script
# ══════════════════════════════════════════════════════════════════
#
# Run this on a fresh Hetzner VPS (Ubuntu 24.04, ARM64 or x86).
#
# Usage:
#   ssh root@<new-ip>
#   curl -sL <raw-url> | bash
#   — OR —
#   scp scripts/provision-staging.sh root@<new-ip>:/tmp/
#   ssh root@<new-ip> 'bash /tmp/provision-staging.sh'
#
# What it does:
#   1. Install Node.js 22.x, PM2, Git
#   2. Clone bre4ch-backend repo
#   3. npm install
#   4. Create .env for staging
#   5. Start PM2 process "bre4ch-staging"
#   6. Open firewall port 3002
#
# ══════════════════════════════════════════════════════════════════

set -euo pipefail

echo "╔══════════════════════════════════════════╗"
echo "║  BRE4CH — Staging Server Provisioning    ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 1. System update ─────────────────────────────────────────────
echo "[1/7] Updating system..."
apt-get update -qq && apt-get upgrade -y -qq

# ── 2. Install Node.js 22.x ─────────────────────────────────────
echo "[2/7] Installing Node.js 22.x..."
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y -qq nodejs
fi
echo "  Node: $(node --version)"
echo "  NPM:  $(npm --version)"

# ── 3. Install PM2 ──────────────────────────────────────────────
echo "[3/7] Installing PM2..."
if ! command -v pm2 &>/dev/null; then
  npm install -g pm2
  pm2 startup systemd -u root --hp /root
fi
echo "  PM2:  $(pm2 --version)"

# ── 4. Clone repository ─────────────────────────────────────────
echo "[4/7] Cloning bre4ch-backend..."
DEPLOY_DIR="/opt/bre4ch"
mkdir -p "$DEPLOY_DIR"

if [ -d "$DEPLOY_DIR/backend/.git" ]; then
  echo "  Repo already exists, pulling latest..."
  cd "$DEPLOY_DIR/backend" && git pull
else
  cd "$DEPLOY_DIR"
  git clone https://github.com/Dilligaf371/bre4ch-backend.git backend
fi

# ── 5. Install dependencies ─────────────────────────────────────
echo "[5/7] Installing npm dependencies..."
cd "$DEPLOY_DIR/backend"
npm install --production

# ── 6. Create staging .env ───────────────────────────────────────
echo "[6/7] Creating .env..."
if [ ! -f "$DEPLOY_DIR/backend/.env" ]; then
  cat > "$DEPLOY_DIR/backend/.env" <<'ENVEOF'
# ── BRE4CH STAGING ──
NODE_ENV=staging
PORT=3002
LOG_LEVEL=debug

# X/Twitter — standby (no streaming on staging)
X_MODE=standby
X_POLL_INTERVAL=300000
X_BEARER_TOKEN=

# Firebase — disabled unless you copy the service account
# FIREBASE_SA_PATH=/opt/bre4ch/firebase-service-account.json

# Admin API key
ADMIN_API_KEY=staging-admin-key
ENVEOF
  echo "  Created .env (staging defaults)"
else
  echo "  .env already exists, skipping"
fi

# ── 7. Start PM2 ────────────────────────────────────────────────
echo "[7/7] Starting PM2 process..."
cd "$DEPLOY_DIR/backend"
pm2 delete bre4ch-staging 2>/dev/null || true
pm2 start src/server.mjs --name bre4ch-staging --node-args="--env-file=.env"
pm2 save

# ── Firewall ─────────────────────────────────────────────────────
if command -v ufw &>/dev/null; then
  ufw allow 3002/tcp 2>/dev/null || true
  echo "  UFW: port 3002 opened"
fi

# ── Done ─────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✓ STAGING SERVER READY                  ║"
echo "╠══════════════════════════════════════════╣"
echo "║                                          ║"
echo "║  API: http://$(hostname -I | awk '{print $1}'):3002   ║"
echo "║  PM2: bre4ch-staging                     ║"
echo "║                                          ║"
echo "║  Test:                                   ║"
echo "║  curl http://localhost:3002/api/health    ║"
echo "║                                          ║"
echo "║  Next steps:                             ║"
echo "║  1. Add IP to Flutter config             ║"
echo "║  2. Copy firebase SA if needed           ║"
echo "║  3. Add X_BEARER_TOKEN if needed         ║"
echo "║                                          ║"
echo "╚══════════════════════════════════════════╝"
