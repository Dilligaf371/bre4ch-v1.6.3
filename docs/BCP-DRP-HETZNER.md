# BRE4CH -- BCP / DRP
## Business Continuity Plan & Disaster Recovery Plan
### Operation Roar of the Lion -- Infrastructure Hetzner

**Version**: 2.0
**Date**: 2026-03-06
**Classification**: INTERNAL -- CONFIDENTIAL

---

## 0. VUE D'ENSEMBLE DU PROJET

**BRE4CH** (Battlefield Real-time Event Assessment & Crisis Hub) est un tableau de bord mobile de renseignement operationnel concu pour le monitoring en temps reel de crises au Moyen-Orient.

| Attribut          | Valeur                                            |
|-------------------|---------------------------------------------------|
| Nom de code       | Roar of the Lion                                  |
| Version           | 1.5.2+1 (Mars 2026)                               |
| Codebase          | ~21 500 lignes Dart, 76 fichiers                  |
| Plateformes       | iOS (TestFlight) + Android                        |
| Framework         | Flutter 3.41 / Dart 3.11                          |
| State Management  | Riverpod 2.6.1 (15 providers)                     |
| Backend           | Express.js 5.2.1 / Node.js 22 LTS                |
| Hebergement       | Hetzner Cloud (2 VPS)                             |
| Process Manager   | PM2                                               |
| Domaine           | api.bre4ch.com                                    |

### 0.1 Architecture fonctionnelle (5 modules)

| Tab      | Route          | Fonction                                                     |
|----------|----------------|--------------------------------------------------------------|
| BRIEF    | /delta-s       | Dashboard synthese -- stats temps reel, fil d'evenements     |
| TRUST    | /crisis-filter | Filtrage menaces -- scoring credibilite, analyse regionale   |
| EVAC     | /evac          | Evacuation -- abris, hopitaux, ambassades, aeroports sur carte |
| CONFLICT | /war-state     | Carte de combat -- NATO APP-6, symbologie couleur/forme      |
| SETTINGS | /settings      | Configuration -- sources, notifications, cartes offline      |

### 0.2 Sources de renseignement

- **31 sources OSINT** (journaux GCC, wire services, agences officielles)
- **SOCMINT** : Telegram, X/Twitter (10+ comptes), Snapchat
- **Militaire** : CENTCOM, DoD.gov
- **Cartographie** : LiveUAMap API, NASA FIRMS
- **~280 headlines** par cycle de refresh (5 min)

### 0.3 Donnees statiques embarquees

| Base         | Entrees | Pays couverts |
|--------------|---------|---------------|
| Hopitaux     | 131     | 8 pays        |
| Abris civils | 100+    | 8 pays        |
| Ambassades   | 50+     | 9 pays        |
| Aeroports    | 30+     | ICAO/IATA     |

### 0.4 Endpoints API backend

| Endpoint                  | Methode | Poll  | Cache TTL | Role                          |
|---------------------------|---------|-------|-----------|-------------------------------|
| /api/sources/headlines    | GET     | 30s   | 5m        | Headlines agreges (280+ art.) |
| /api/sources/status       | GET     | 60s   | 1m        | Sante des 31 sources          |
| /api/sources/refresh      | POST    | --    | --        | Forcer refresh RSS            |
| /api/liveuamap            | GET     | 90s   | 5m        | Evenements LiveUAMap          |
| /api/centcom/briefings    | GET     | 60s   | 10m       | Briefings CENTCOM             |
| /api/forces/axis          | GET     | --    | 15m       | Positions forces axe          |
| /api/forces/coalition     | GET     | --    | 15m       | Positions forces coalition    |
| /api/cyber                | GET     | --    | 10m       | Menaces cyber                 |
| /api/stats/baseline       | GET     | --    | 5m        | Stats baseline                |
| /api/airports/status      | GET     | 90s   | 5m        | Statut aeroports              |
| /api/notifications/register | POST  | --    | --        | Enregistrement FCM            |
| /api/health               | GET     | --    | --        | Health check                  |

### 0.5 Cles API et services externes

| Service              | Variable d'environnement  | Usage                              |
|----------------------|---------------------------|------------------------------------|
| Anthropic Claude     | ANTHROPIC_API_KEY         | Agent C2 (JARVIS) -- intelligence  |
| LiveUAMap            | LIVEUAMAP_API_KEY         | Evenements geolocalises temps reel |
| Google Maps          | VITE_GOOGLE_MAPS_API_KEY  | Cartographie frontend              |
| Firebase FCM         | Firebase Admin SDK        | Notifications push                 |
| Ollama (local)       | OLLAMA_URL                | Agent ULTRON -- LLM tactique       |

### 0.6 Stack technique complet

| Couche            | Technologie                      | Version  |
|-------------------|----------------------------------|----------|
| Framework mobile  | Flutter                          | 3.41     |
| Langage mobile    | Dart                             | 3.11     |
| State Management  | Riverpod                         | 2.6.1    |
| Routing           | GoRouter                         | 14.8.1   |
| HTTP Client       | Dio + Cache Interceptor          | 5.8.0    |
| Cartographie      | Flutter Map + latlong2           | 7.0.2    |
| GPS               | Geolocator                       | 13.0.2   |
| Charts            | fl_chart                         | 0.70.2   |
| Notifications     | Firebase Messaging               | 15.2.4   |
| Backend           | Express.js                       | 5.2.1    |
| Runtime           | Node.js                          | 22 LTS   |
| WebSocket         | ws                               | 8.19.0   |
| Process Manager   | PM2                              | 6.0.14   |
| Reverse Proxy     | Nginx                            | 1.24.0   |
| SSL               | Let's Encrypt (Certbot)          | auto     |

---

## 1. ARCHITECTURE INFRASTRUCTURE

### 1.1 Vue d'ensemble

```
                                    INTERNET
                                       |
                              +--------v---------+
                              |   DNS (A Record) |
                              | api.bre4ch.com   |
                              +--------+---------+
                                       |
                    ACTIF              |              STANDBY (DRP)
         +---------v----------+        |     +----------v---------+
         |  PROD -- NBG1      |        |     |  DRP -- HEL1       |
         |  ubuntu-4gb-nbg1-1 |        |     |  bre4ch-drp        |
         |  178.104.30.109    |        |     |  135.181.111.247   |
         |                    |        |     |                    |
         |  Nginx :80/:443   |        |     |  Nginx :80         |
         |  Express :3002     |        |     |  Express :3002     |
         |  PM2 (bre4ch-api)  |        |     |  PM2 (bre4ch-api)  |
         |  UFW + Tailscale   |        |     |  UFW + Tailscale   |
         +--------------------+        |     +--------------------+
                |                      |              |
                |      Tailscale Mesh Network         |
                +------------------+------------------+
                                   |
                    +--------v---------+
                    | Admin Mac Studio |
                    | jarviss-mac-studio|
                    | 100.83.241.2     |
                    +------------------+
```

### 1.2 Inventaire des serveurs

| Attribut          | PROD (Primaire)            | DRP (Standby)              |
|-------------------|----------------------------|----------------------------|
| Nom Hetzner       | ubuntu-4gb-nbg1-1          | bre4ch-drp                 |
| Hetzner ID        | 122762028                  | 122901209                  |
| Localisation      | NBG1 (Nuremberg, DE)       | HEL1 (Helsinki, FI)       |
| Type              | CX (x86, 4GB)              | CAX11 (ARM, 4GB)           |
| IP publique       | 178.104.30.109             | 135.181.111.247            |
| Tailscale IP      | --                         | 100.102.106.55             |
| Tailscale name    | --                         | bre4ch-drp                 |
| OS                | Ubuntu 24.04.3 LTS         | Ubuntu 24.04 LTS           |
| Node.js           | v22.22.0                   | v22.22.1                   |
| PM2               | 5.x                        | 6.0.14                     |
| Nginx             | 1.24.0                     | 1.24.0                     |
| Certbot           | oui                        | oui (SSL apres DNS switch) |
| UFW               | actif                      | actif (22/80/443/41641)    |
| Tailscale SSH     | oui                        | oui                        |
| App directory     | /opt/bre4ch/backend        | /opt/bre4ch/backend        |
| Logs              | /var/log/bre4ch/           | /var/log/bre4ch/           |
| Backups auto      | Hetzner snapshots actifs   | Hetzner snapshots actifs   |
| Log rotation      | --                         | /etc/logrotate.d/bre4ch    |
| Backup cron       | --                         | /etc/cron.d/bre4ch-backup  |
| Health monitoring | --                         | /etc/cron.d/bre4ch-healthcheck |
| Snapshot initial  | --                         | Image 363990222            |
| Role              | ACTIF -- sert le trafic    | STANDBY FROID -- failover  |

### 1.3 Tailscale Mesh Network

| Hostname           | IP Tailscale     | OS      | Role                |
|--------------------|------------------|---------|---------------------|
| jarviss-mac-studio | 100.83.241.2     | macOS   | Admin / Dev         |
| gilless-laptop     | 100.82.165.75    | macOS   | Admin backup        |
| ailfred            | 100.94.159.125   | linux   | VPS Hetzner (autre) |
| bre4ch-drp         | 100.102.106.55   | linux   | VPS DRP BRE4CH      |

### 1.4 Configuration Nginx (cible PROD)

```nginx
server {
    listen 80;
    server_name api.bre4ch.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.bre4ch.com;

    ssl_certificate     /etc/letsencrypt/live/api.bre4ch.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.bre4ch.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    add_header X-Frame-Options       "SAMEORIGIN"  always;
    add_header X-Content-Type-Options "nosniff"     always;
    add_header X-XSS-Protection      "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    limit_req zone=api burst=60 nodelay;

    location / {
        proxy_pass         http://127.0.0.1:3002;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_set_header   Upgrade           $http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_read_timeout 300s;
    }

    location ~ /\. { deny all; }
}
```

### 1.5 Configuration PM2

```javascript
module.exports = {
  apps: [{
    name: 'bre4ch-api',
    script: 'src/server.mjs',
    cwd: '/opt/bre4ch/backend',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    max_restarts: 10,
    restart_delay: 5000,
    watch: false,
    max_memory_restart: '512M',
    env: {
      NODE_ENV: 'production',
      ULTRON_PORT: '3002',
    },
    error_file: '/var/log/bre4ch/error.log',
    out_file: '/var/log/bre4ch/out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    merge_logs: true,
  }],
};
```

---

## 2. ANALYSE DES RISQUES

| # | Risque                          | Probabilite | Impact   | RTO      | RPO      |
|---|--------------------------------|-------------|----------|----------|----------|
| 1 | Crash applicatif (Node.js)     | Moyenne     | Faible   | < 10 sec | 0        |
| 2 | Saturation memoire             | Moyenne     | Moyen    | < 30 sec | 0        |
| 3 | Expiration certificat SSL      | Faible      | Eleve    | < 15 min | 0        |
| 4 | Panne VPS Hetzner              | Faible      | Critique | < 2h     | 0        |
| 5 | Corruption filesystem          | Tres faible | Critique | < 4h     | < 24h    |
| 6 | Compromission serveur          | Faible      | Critique | < 4h     | < 1h     |
| 7 | Panne datacenter Hetzner       | Tres faible | Critique | < 1h *   | 0        |
| 8 | Attaque DDoS                   | Moyenne     | Eleve    | < 1h     | 0        |
| 9 | Erreur humaine (bad deploy)    | Moyenne     | Moyen    | < 30 min | 0        |
|10 | Perte cles API (Anthropic etc) | Faible      | Eleve    | < 1h     | 0        |

*RTO = Recovery Time Objective (temps pour restaurer le service)
*RPO = Recovery Point Objective (perte de donnees acceptable)
* RTO scenario 7 ameliore grace au DRP standby HEL1

---

## 3. BUSINESS CONTINUITY PLAN (BCP)

### 3.1 Mesures preventives ACTIVES

**Auto-healing applicatif**
- PM2 auto-restart en cas de crash (max 10 restarts, delay 5s)
- PM2 redemarrage auto si memoire > 512 MB
- PM2 enregistre dans systemd (survit au reboot VPS)

**Securite reseau**
- UFW firewall actif (ports minimaux: 22, 80, 443, 41641/udp)
- Nginx rate limiting (30 req/s par IP, burst 60)
- TLS 1.2/1.3 uniquement
- HSTS, X-Frame-Options, X-Content-Type-Options
- Acces SSH via Tailscale uniquement
- Dot-files bloques par Nginx

**Certificat SSL**
- Let's Encrypt via Certbot
- Renouvellement automatique (certbot.timer systemd)

**Sauvegardes Hetzner (ACTIF)**
- Snapshots automatiques actives sur PROD (ID 122762028)
- Snapshots automatiques actives sur DRP (ID 122901209)
- Snapshot initial DRP: Image 363990222 (2026-03-06)

**Serveur DRP standby froid (ACTIF)**
- VPS bre4ch-drp (135.181.111.247) -- Helsinki HEL1
- Backend identique deploye et fonctionnel
- PM2 bre4ch-api en ligne
- Failover DNS manuel en < 15 min

**Monitoring (ACTIF sur DRP)**
- Health check cron toutes les 5 min (/etc/cron.d/bre4ch-healthcheck)
- Verifie PROD (178.104.30.109:3002) et DRP (localhost:3002)
- Log: /var/log/bre4ch/healthcheck.log

**Backup cron (ACTIF sur DRP)**
- Backup quotidien 03h00: .env + ecosystem.config + nginx + certs
- Retention: 30 jours
- Fichier: /etc/cron.d/bre4ch-backup

**Log rotation (ACTIF sur DRP)**
- Rotation quotidienne, retention 14 jours, compression
- Fichier: /etc/logrotate.d/bre4ch

### 3.2 Mesures A IMPLEMENTER

| Priorite | Action                                 | Effort | Impact   | Statut   |
|----------|----------------------------------------|--------|----------|----------|
| P1       | Snapshots Hetzner auto                 | 5 min  | Critique | FAIT     |
| P1       | Backup cron .env + configs             | 15 min | Critique | FAIT     |
| P1       | Health monitoring                      | 10 min | Eleve    | FAIT     |
| P1       | Log rotation                           | 5 min  | Moyen    | FAIT     |
| P1       | VPS DRP standby (second datacenter)    | 2h     | Critique | FAIT     |
| P2       | Cloudflare DNS + proxy                 | 30 min | Eleve    | A FAIRE  |
| P2       | Alertes Telegram/email si API down     | 20 min | Eleve    | A FAIRE  |
| P2       | Backup cron sur PROD aussi             | 10 min | Eleve    | A FAIRE  |
| P2       | Log rotation sur PROD                  | 5 min  | Moyen    | A FAIRE  |
| P3       | CI/CD pipeline (GitHub Actions)        | 3h     | Moyen    | A FAIRE  |
| P3       | Containerisation Docker                | 4h     | Moyen    | A FAIRE  |
| P3       | Failover DNS automatique (Cloudflare)  | 1h     | Eleve    | A FAIRE  |

---

## 4. DISASTER RECOVERY PLAN (DRP)

### 4.1 SCENARIO 1 -- Crash applicatif

**Symptome**: API ne repond plus, WebSocket deconnecte
**Impact**: Faible (auto-recovery)
**RTO**: < 10 secondes

```
AUTOMATIQUE:
  PM2 detecte le crash -> restart auto (delay 5s, max 10)

SI PM2 STOP (max restarts atteint):
  1. ssh root@178.104.30.109           # PROD
     ssh root@100.102.106.55           # ou DRP via Tailscale

  2. pm2 logs bre4ch-api --lines 50
     tail -50 /var/log/bre4ch/error.log

  3. cd /opt/bre4ch && pm2 delete bre4ch-api && pm2 start ecosystem.config.cjs && pm2 save

  4. curl -s https://api.bre4ch.com/api/health
```

### 4.2 SCENARIO 2 -- Saturation memoire

**Symptome**: Latence extreme, OOM killer
**Impact**: Moyen
**RTO**: < 30 secondes

```
AUTOMATIQUE: PM2 redemarre si > 512 MB

SI PERSISTANT:
  1. ssh root@<VPS>
  2. free -h && pm2 monit && top -o %MEM
  3. pm2 restart bre4ch-api
  4. Si recurrent: Hetzner Console > Serveur > Resize (downtime < 5 min)
```

### 4.3 SCENARIO 3 -- Certificat SSL expire

**Symptome**: ERR_CERT_DATE_INVALID, app mobile refuse connexion
**Impact**: Eleve
**RTO**: < 15 minutes

```
  1. ssh root@<VPS>
  2. openssl x509 -enddate -noout -in /etc/letsencrypt/live/api.bre4ch.com/fullchain.pem
  3. certbot renew --force-renewal
  4. nginx -t && systemctl reload nginx
  5. curl -vI https://api.bre4ch.com 2>&1 | grep "expire date"

PREVENTION: systemctl status certbot.timer (doit etre actif)
```

### 4.4 SCENARIO 4 -- Panne VPS PROD

**Symptome**: PROD injoignable, health check echoue
**Impact**: Critique
**RTO**: < 1 heure (grace au DRP)

```
  1. Verifier https://status.hetzner.com

  2. Si PROD HS > 10 min:
     BASCULER SUR DRP:
     a. Changer DNS api.bre4ch.com -> 135.181.111.247 (DRP)
     b. Sur DRP, activer SSL:
        ssh root@100.102.106.55
        certbot --nginx -d api.bre4ch.com --non-interactive --agree-tos -m admin@bre4ch.com
     c. Deployer la config Nginx SSL complete
     d. Verifier: curl -s https://api.bre4ch.com/api/health

  3. Apres resolution PROD:
     - Resynchroniser le code et .env
     - Remettre DNS sur PROD (178.104.30.109)
     - Remettre DRP en standby
```

### 4.5 SCENARIO 5 -- Panne datacenter (NBG1)

**Symptome**: Tout le DC Nuremberg est HS
**Impact**: Critique
**RTO**: < 1 heure (DRP sur HEL1 -- datacenter different)

```
  Procedure identique au scenario 4.4
  Le DRP est a Helsinki (HEL1), independant de Nuremberg (NBG1)

  1. DNS api.bre4ch.com -> 135.181.111.247
  2. Activer SSL sur DRP
  3. Verifier health check

  Le DRP est deja operationnel, PM2 en ligne.
```

### 4.6 SCENARIO 6 -- Compromission serveur

**Symptome**: Activite suspecte, processus inconnus, logs alteres
**Impact**: Critique
**RTO**: < 4 heures

```
  IMMEDIAT:
  1. Isoler le serveur (Hetzner Console > couper reseau OU ufw deny all)

  2. Capturer les preuves:
     tar czf /root/incident-$(date +%Y%m%d-%H%M).tar.gz /var/log/ /opt/bre4ch/backend/.env /var/log/bre4ch/
     ps auxf > /root/incident-ps.txt
     ss -tlnp > /root/incident-netstat.txt

  3. Basculer immediatement sur DRP (scenario 4.4)

  4. Rotation des secrets:
     - ANTHROPIC_API_KEY (console.anthropic.com)
     - LIVEUAMAP_API_KEY
     - VITE_GOOGLE_MAPS_API_KEY (console.cloud.google.com)
     - Credentials auth (VITE_AUTH_USER/PASS)
     - Cles Tailscale si necessaire

  5. Rebuild PROD:
     - Detruire le VPS compromis
     - Creer nouveau VPS depuis snapshot clean
     - Deployer avec deploy.sh
     - Injecter nouveau .env avec cles regenerees

  6. Post-mortem: analyser logs, identifier vecteur, documenter
```

### 4.7 SCENARIO 7 -- Attaque DDoS

**Symptome**: Latence extreme, Nginx 429/503, saturation bande passante
**Impact**: Eleve
**RTO**: < 1 heure

```
  NIVEAU 1: Rate limiting existant (30 req/s, burst 60)

  NIVEAU 2: Blocage IP
     tail -1000 /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
     ufw deny from <IP_ABUSIVE>

  NIVEAU 3: Cloudflare (recommande)
     - Activer proxy (nuage orange)
     - Under Attack Mode si necessaire
     - Protection L7 automatique

  NIVEAU 4: Hetzner DDoS Protection (L3/L4 inclus gratuitement)
```

### 4.8 SCENARIO 8 -- Bad deploy

**Symptome**: API errors apres deploiement
**Impact**: Moyen
**RTO**: < 30 minutes

```
  1. Rollback depuis GitHub:
     ssh root@<VPS>
     cd /opt/bre4ch/backend
     git checkout <COMMIT_STABLE>
     npm ci --omit=dev
     cd /opt/bre4ch && pm2 restart bre4ch-api

  2. OU redeploy depuis Mac:
     cd ~/Desktop/roar-of-the-lion-v2
     git checkout <TAG_STABLE>
     export BRE4CH_VPS=<TAILSCALE_IP>
     bash deploy/deploy.sh

  3. curl -s https://api.bre4ch.com/api/health
```

---

## 5. PROCEDURE DE FAILOVER PROD -> DRP

### Procedure complete de basculement

```
ETAPE 1 -- DECISION (< 5 min)
  - Confirmer que PROD est HS (health check echoue 3x de suite)
  - Verifier DRP operationnel: ssh root@100.102.106.55 "pm2 status && curl -s http://localhost:3002/api/health"

ETAPE 2 -- BASCULEMENT DNS (< 10 min)
  - Connecter au provider DNS
  - Modifier A record: api.bre4ch.com -> 135.181.111.247
  - TTL: 300s (propagation < 5 min)

ETAPE 3 -- ACTIVATION SSL SUR DRP (< 5 min)
  ssh root@100.102.106.55
  certbot --nginx -d api.bre4ch.com --non-interactive --agree-tos -m admin@bre4ch.com
  # Deployer la config Nginx SSL complete (voir section 1.4)
  nginx -t && systemctl reload nginx

ETAPE 4 -- VERIFICATION (< 5 min)
  curl -s https://api.bre4ch.com/api/health
  # Tester WebSocket: wscat -c wss://api.bre4ch.com/ws

ETAPE 5 -- RETOUR SUR PROD (quand PROD est retabli)
  - Verifier PROD operationnel
  - Resynchroniser .env et code si necessaire
  - Remettre DNS sur 178.104.30.109
  - Remettre DRP en standby
```

---

## 6. PROCEDURES OPERATIONNELLES

### 6.1 Deploiement standard

```bash
# Depuis Mac
cd ~/Desktop/roar-of-the-lion-v2
export BRE4CH_VPS=178.104.30.109    # PROD
bash deploy/deploy.sh

# Pour mettre a jour le DRP aussi:
export BRE4CH_VPS=100.102.106.55    # DRP via Tailscale
bash deploy/deploy.sh
```

### 6.2 Verification quotidienne

```
[ ] Health PROD:  curl -s http://178.104.30.109:3002/api/health
[ ] Health DRP:   ssh root@100.102.106.55 "curl -s http://localhost:3002/api/health"
[ ] PM2 PROD:     ssh root@178.104.30.109 "pm2 status"
[ ] PM2 DRP:      ssh root@100.102.106.55 "pm2 status"
[ ] Memoire:      ssh root@<VPS> "free -h"
[ ] Disque:       ssh root@<VPS> "df -h /"
[ ] Logs erreur:  ssh root@<VPS> "tail -20 /var/log/bre4ch/error.log"
[ ] SSL:          ssh root@<VPS> "certbot certificates"
[ ] Monitoring:   ssh root@100.102.106.55 "tail -10 /var/log/bre4ch/healthcheck.log"
```

### 6.3 Commandes utiles

```bash
# Status complet d'un serveur
ssh root@<VPS> "pm2 status && free -h && df -h / && uptime"

# Logs temps reel
ssh root@<VPS> "pm2 logs bre4ch-api"

# Restart rapide
ssh root@<VPS> "pm2 restart bre4ch-api"

# Reload Nginx sans downtime
ssh root@<VPS> "nginx -t && systemctl reload nginx"

# Connexions WebSocket actives
ssh root@<VPS> "ss -tnp | grep 3002 | wc -l"

# Tester WebSocket
wscat -c wss://api.bre4ch.com/ws

# Synchroniser PROD -> DRP
rsync -avz --delete --exclude 'node_modules' --exclude '.env' \
  root@178.104.30.109:/opt/bre4ch/backend/ \
  root@100.102.106.55:/opt/bre4ch/backend/
```

---

## 7. CONTACTS & ESCALADE

| Niveau | Condition                    | Action                              | Contact               |
|--------|------------------------------|-------------------------------------|-----------------------|
| L0     | Crash Node.js                | Auto-recovery PM2                   | Automatique           |
| L1     | PM2 max restarts             | Restart manuel via SSH              | Admin (Tailscale)     |
| L2     | PROD HS > 10 min             | Basculer sur DRP (section 5)        | Admin                 |
| L3     | Rebuild necessaire           | Nouveau VPS depuis snapshot         | Admin + Hetzner       |
| L4     | Panne datacenter             | DRP prend le relai automatiquement  | Admin + Hetzner       |

**Liens utiles:**
- Hetzner Cloud Console: https://console.hetzner.cloud
- Hetzner Status: https://status.hetzner.com
- Tailscale Admin: https://login.tailscale.com/admin
- Let's Encrypt Status: https://letsencrypt.status.io
- GitHub Repo: https://github.com/Dilligaf371/bre4ch-v1.6

---

## 8. DIAGRAMME DE DEPLOIEMENT

```
+---------------------+     +----------------------------+
|   App Flutter iOS    |---->|  api.bre4ch.com (HTTPS)    |
|   (TestFlight)       |     |                            |
|                      |     |  PROD: 178.104.30.109      |
|  +----------------+  |     |  DRP:  135.181.111.247     |
|  | Dio + Cache    |--+---->|                            |
|  | WebSocket      |  |     |  Express.js + PM2          |
|  | FCM Client     |--+-+   |  +-- sources.mjs (31 RSS) |
|  | Flutter Map    |  | |   |  +-- centcom.mjs           |
|  | Geolocator     |  | |   |  +-- forces.mjs            |
|  | SharedPrefs    |  | |   |  +-- cyber.mjs             |
|  +----------------+  | |   |  +-- liveuamap.mjs         |
+---------------------+ | |   |  +-- notifications.mjs    |
                         | |   +----------------------------+
                         | |
                         | +-->+------------------+
                         |     | Firebase Cloud   |
                         |     | Messaging (FCM)  |
                         |     | Topics:          |
                         |     | breach_country_* |
                         |     | breach_city_*    |
                         |     | breach_type_*    |
                         |     | breach_severity_*|
                         |     +------------------+
                         |
                         +---->+------------------+
                               | Services externes|
                               | Anthropic Claude |
                               | LiveUAMap API    |
                               | Google Maps      |
                               | Ollama (local)   |
                               +------------------+
```

---

## 9. HISTORIQUE DES REVISIONS

| Version | Date       | Auteur | Changement                                          |
|---------|------------|--------|-----------------------------------------------------|
| 1.0     | 2026-03-05 | JARVIS | Creation initiale                                   |
| 2.0     | 2026-03-06 | JARVIS | Ajout VPS DRP HEL1, vue d'ensemble projet, cles API, procedure failover, inventaire complet |

---

*Ce document doit etre revu et mis a jour a chaque changement majeur d'infrastructure.*
*Prochaine revue recommandee: 2026-04-06*
