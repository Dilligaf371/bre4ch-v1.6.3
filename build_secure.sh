#!/usr/bin/env bash
# ── BRE4CH Secure Build ──────────────────────────────────────────
# HIGH-03: Obfuscation + split debug info + env-injected secrets.
# CRIT-03: API keys passed via --dart-define, never hardcoded.
#
# Usage:
#   GOOGLE_MAPS_API_KEY=<key> BREACH_API_KEY=<key> ./build_secure.sh ios
#   GOOGLE_MAPS_API_KEY=<key> BREACH_API_KEY=<key> ./build_secure.sh android
#
# Prerequisites: flutter SDK in PATH

set -euo pipefail

TARGET="${1:-ios}"
BUILD_DIR="build/debug-info-$(date +%Y%m%d-%H%M%S)"

# ── Validate required env vars ──────────────────────────────────
: "${GOOGLE_MAPS_API_KEY:?Set GOOGLE_MAPS_API_KEY}"
: "${BREACH_API_KEY:?Set BREACH_API_KEY}"

# Optional overrides
API_BASE="${API_BASE:-https://api.bre4ch.com}"
WS_URL="${WS_URL:-}"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  BRE4CH SECURE BUILD — $(date -u +"%Y-%m-%d %H:%M UTC")          ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Target:   $TARGET"
echo "║  API Base: $API_BASE"
echo "║  Debug:    $BUILD_DIR"
echo "╚══════════════════════════════════════════════════════════╝"

DART_DEFINES=(
  --dart-define="GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY"
  --dart-define="BREACH_API_KEY=$BREACH_API_KEY"
  --dart-define="API_BASE=$API_BASE"
)
[ -n "$WS_URL" ] && DART_DEFINES+=(--dart-define="WS_URL=$WS_URL")

mkdir -p "$BUILD_DIR"

case "$TARGET" in
  ios)
    echo "[BUILD] Flutter build IPA (release + obfuscated)..."
    flutter build ipa \
      --release \
      --obfuscate \
      --split-debug-info="$BUILD_DIR" \
      "${DART_DEFINES[@]}"
    echo "[OK] IPA built. Debug symbols: $BUILD_DIR"
    ;;
  android)
    echo "[BUILD] Flutter build APK (release + obfuscated)..."
    flutter build apk \
      --release \
      --obfuscate \
      --split-debug-info="$BUILD_DIR" \
      "${DART_DEFINES[@]}"
    echo "[OK] APK built. Debug symbols: $BUILD_DIR"
    ;;
  *)
    echo "[ERROR] Unknown target: $TARGET (use ios or android)"
    exit 1
    ;;
esac

echo ""
echo "IMPORTANT: Keep $BUILD_DIR for crash symbolication."
echo "           Never commit debug symbols to version control."
