# ══════════════════════════════════════════════════════════════════
# BRE4CH — Development & Deployment Makefile
# ══════════════════════════════════════════════════════════════════
#
#   make help          — Show all commands
#
#   DEVELOPMENT (local)
#   make dev-backend   — Local backend on port 3003
#   make dev-app       — Flutter → local backend
#
#   STAGING (Hetzner)
#   make staging-app   — Flutter → staging server
#   make staging-deploy— Deploy backend to staging
#   make staging-logs  — Tail staging PM2 logs
#
#   PRODUCTION
#   make prod-app      — Flutter → production API
#   make deploy        — Deploy backend to PROD + DRP
#   make ship          — analyze + test + build IPA + upload
#
# ══════════════════════════════════════════════════════════════════

# ── Config ───────────────────────────────────────────────────────
LOCAL_IP     := $(shell ipconfig getifaddr en0 2>/dev/null || echo "localhost")
DEV_PORT     := 3003
DEV_API      := http://$(LOCAL_IP):$(DEV_PORT)
PROD_API     := https://api.bre4ch.com
PROD_HOST    := root@178.104.30.109
DRP_HOST     := root@135.181.111.247

# ── STAGING (Hetzner Helsinki, CAX11 ARM) ──
STAGING_HOST := root@89.167.121.131
STAGING_API  := http://89.167.121.131:3002

BACKEND_DIR  := backend
IPA_PATH     := build/ios/ipa/breach.ipa

.PHONY: help dev dev-backend dev-app staging-app staging-deploy staging-provision staging-logs staging-status prod-app analyze test check build upload ship deploy deploy-prod deploy-drp status logs-prod logs-drp dev-status clean

help: ## Show all commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ══════════════════════════════════════════════════════════════════
# LOCAL DEVELOPMENT
# ══════════════════════════════════════════════════════════════════

dev-backend: ## Start local backend (port 3003, no Firebase/X)
	@echo "┌─────────────────────────────────────────┐"
	@echo "│  BRE4CH DEV BACKEND — $(DEV_API)        │"
	@echo "│  Firebase: OFF  |  X: standby           │"
	@echo "│  Ctrl+C to stop                         │"
	@echo "└─────────────────────────────────────────┘"
	cd $(BACKEND_DIR) && cp .env.dev .env && node src/server.mjs

dev-app: ## Run Flutter app → local backend
	@echo "[DEV] Flutter → $(DEV_API)"
	flutter run --dart-define=API_BASE=$(DEV_API)

dev-status: ## Check local dev backend health
	@curl -s http://localhost:$(DEV_PORT)/api/health | python3 -m json.tool 2>/dev/null || echo "DEV backend not running"

# ══════════════════════════════════════════════════════════════════
# STAGING (Hetzner)
# ══════════════════════════════════════════════════════════════════

staging-provision: ## Provision a new staging server (run once)
	@echo "[STAGING] Provisioning $(STAGING_HOST)..."
	scp scripts/provision-staging.sh $(STAGING_HOST):/tmp/provision-staging.sh
	ssh $(STAGING_HOST) 'bash /tmp/provision-staging.sh'

staging-app: ## Run Flutter app → staging server
	@echo "[STAGING] Flutter → $(STAGING_API)"
	flutter run --dart-define=API_BASE=$(STAGING_API)

staging-deploy: ## Deploy backend to staging
	@echo "[STAGING] Deploying to $(STAGING_HOST)..."
	ssh $(STAGING_HOST) 'cd /opt/bre4ch/backend && git pull && pm2 restart bre4ch-staging'
	@echo "✓ Staging deployed"

staging-logs: ## Tail staging PM2 logs
	ssh $(STAGING_HOST) 'pm2 logs bre4ch-staging --lines 50'

staging-status: ## Check staging health
	@echo "── STAGING ──"
	@curl -s $(STAGING_API)/api/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "OFFLINE"

staging-copy-firebase: ## Copy Firebase SA from PROD to staging
	@echo "[STAGING] Copying Firebase service account..."
	scp $(PROD_HOST):/opt/bre4ch/firebase-service-account.json /tmp/firebase-sa.json
	scp /tmp/firebase-sa.json $(STAGING_HOST):/opt/bre4ch/firebase-service-account.json
	rm /tmp/firebase-sa.json
	@echo "✓ Firebase SA copied. Enable it in staging .env:"
	@echo "  ssh $(STAGING_HOST) 'vi /opt/bre4ch/backend/.env'"
	@echo "  Uncomment FIREBASE_SA_PATH line, then: pm2 restart bre4ch-staging"

# ══════════════════════════════════════════════════════════════════
# PRODUCTION
# ══════════════════════════════════════════════════════════════════

prod-app: ## Run Flutter app → production API
	@echo "[PROD] Flutter → $(PROD_API)"
	flutter run --dart-define=API_BASE=$(PROD_API)

# ══════════════════════════════════════════════════════════════════
# QUALITY
# ══════════════════════════════════════════════════════════════════

analyze: ## Run flutter analyze
	flutter analyze

test: ## Run flutter test
	flutter test

check: analyze test ## Run analyze + test

# ══════════════════════════════════════════════════════════════════
# BUILD & DEPLOY
# ══════════════════════════════════════════════════════════════════

build: check ## Build IPA (production) after analyze+test
	flutter build ipa
	@echo "✓ IPA ready: $(IPA_PATH)"
	@ls -lh $(IPA_PATH)

upload: ## Upload IPA to TestFlight via Transporter
	open -a Transporter $(IPA_PATH)

ship: build upload ## Full pipeline: check → build → upload

deploy-prod: ## Deploy backend to PROD
	@echo "[DEPLOY] PROD $(PROD_HOST)..."
	ssh $(PROD_HOST) 'cd /opt/bre4ch/backend && git pull && pm2 restart bre4ch-api'
	@echo "✓ PROD deployed"

deploy-drp: ## Deploy backend to DRP
	@echo "[DEPLOY] DRP $(DRP_HOST)..."
	ssh $(DRP_HOST) 'cd /opt/bre4ch/backend && git pull && pm2 restart bre4ch-api'
	@echo "✓ DRP deployed"

deploy: deploy-prod deploy-drp ## Deploy backend to PROD + DRP
	@echo "✓ Both servers deployed"

# ══════════════════════════════════════════════════════════════════
# MONITORING
# ══════════════════════════════════════════════════════════════════

status: ## Check all servers health
	@echo "── PROD ──"
	@curl -s $(PROD_API)/api/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "OFFLINE"
	@echo ""
	@echo "── DRP ──"
	@curl -s http://135.181.111.247:3002/api/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "OFFLINE"
	@echo ""
	@echo "── STAGING ──"
	@curl -s $(STAGING_API)/api/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "OFFLINE or not configured"

logs-prod: ## Tail PROD PM2 logs
	ssh $(PROD_HOST) 'pm2 logs bre4ch-api --lines 50'

logs-drp: ## Tail DRP PM2 logs
	ssh $(DRP_HOST) 'pm2 logs bre4ch-api --lines 50'

# ══════════════════════════════════════════════════════════════════
# CLEANUP
# ══════════════════════════════════════════════════════════════════

clean: ## Clean Flutter build artifacts
	flutter clean
	@echo "✓ Cleaned"
