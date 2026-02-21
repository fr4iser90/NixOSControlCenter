# Nixify Web Service - Deployment Guide

## Docker Deployment mit Traefik

### Voraussetzungen

- Docker & Docker Compose
- Traefik mit `proxy` Netzwerk
- Internet-Verbindung (für automatisches Repository-Klonen)

**Hinweis:** Das Repository wird automatisch beim Container-Start von GitHub geklont. Ein manuelles Klonen ist nicht mehr nötig!

### Deployment

1. **Docker Compose starten:**
   ```bash
   cd nixos/modules/specialized/nixify/web-service/docker
   docker-compose -f docker-compose.traefik.yml up -d
   ```
   
   Der Container klont beim ersten Start automatisch das Repository von GitHub.

2. **Service ist erreichbar unter:**
   - `https://nixify.fr4iser` (via Traefik)

### Volumes & Mounts

Die folgenden Verzeichnisse werden gemountet, damit Updates ohne Rebuild möglich sind:

- **Snapshot Scripts**: `/app/snapshot/` → `./nixos/modules/specialized/nixify/snapshot`
- **Mapping Database**: `/app/mapping/` → `./nixos/modules/specialized/nixify/mapping`
- **Config Generator**: `/app/config-generator/` → `./nixos/modules/specialized/nixify/web-service/config-generator`
- **ISO Builder**: `/app/iso-builder/` → `./nixos/modules/specialized/nixify/iso-builder`
- **NixOS Repo**: `/app/nixos/` → `./nixos` (für Generator/ISO-Builder)

### Scripts aktualisieren ohne Rebuild

1. Scripts im Repository bearbeiten:
   ```bash
   vim nixos/modules/specialized/nixify/snapshot/windows/nixify-scan.ps1
   ```

2. Container neu starten (lädt gemountete Scripts neu):
   ```bash
   cd nixos/modules/specialized/nixify/web-service/docker
   docker-compose -f docker-compose.traefik.yml restart nixify-service
   ```

**Hinweis:** Die gemounteten Scripts haben **Vorrang** vor den eingebetteten Scripts. Falls ein gemountetes Script nicht existiert, wird automatisch das eingebettete Script verwendet (Fallback).

### Mapping Database aktualisieren

1. Mapping Database bearbeiten:
   ```bash
   vim nixos/modules/specialized/nixify/mapping/mapping-database.json
   ```

2. Container neu starten:
   ```bash
   cd nixos/modules/specialized/nixify/web-service/docker
   docker-compose -f docker-compose.traefik.yml restart nixify-service
   ```

### Logs anzeigen

```bash
cd nixos/modules/specialized/nixify/web-service/docker
docker-compose -f docker-compose.traefik.yml logs -f nixify-service
```

### Health Check

```bash
curl https://nixify.fr4iser/api/v1/health
```

### Traefik Konfiguration

Das Service ist bereits für Traefik konfiguriert:
- **Host**: `nixify.fr4iser`
- **TLS**: Automatisch via Let's Encrypt (`http_resolver`)
- **Port**: 8080 (intern)
- **Network**: `proxy` (extern)

### Automatisches Repository-Klonen

**Wichtig:** Beim Container-Start wird automatisch das NixOS Control Center Repository von GitHub geklont und die `nixos/` Struktur nach `/app/nixos` kopiert.

**Wie es funktioniert:**
1. Container startet → Init-Script wird ausgeführt
2. Prüft, ob `/app/nixos` bereits existiert
3. Falls nicht: Klont Repository von GitHub (Branch: `main` oder `GITHUB_BRANCH`)
4. Kopiert `nixos/` Struktur nach `/app/nixos`
5. Startet den Web-Service

**Vorteile:**
- ✅ Container hat immer die neueste Version
- ✅ Kein manuelles Klonen nötig
- ✅ Funktioniert auch ohne lokales Repository
- ✅ Einfaches Update: Container neu starten

**Konfiguration:**
- `GITHUB_REPO_URL` - GitHub Repository URL (default: `https://github.com/fr4iser90/NixOSControlCenter.git`)
- `GITHUB_BRANCH` - Branch zum Klonen (default: `main`)

### Environment Variables

- `PORT=8080` - Service Port
- `HOST=0.0.0.0` - Bind Address
- `DATA_DIR=/var/lib/nixify` - Data Directory
- `MAPPING_DB_PATH=/app/mapping/mapping-database.json` - Mapping Database Path
- `MODULES_BASE_PATH=/app/nixos` - NixOS Modules Base Path (wird automatisch gesetzt)
- `GITHUB_REPO_URL` - GitHub Repository URL für automatisches Klonen
- `GITHUB_BRANCH` - Branch zum Klonen (default: `main`)
- `SHOW_STATUS_BADGE=true` - Zeige Active/Disabled Status-Badges in der Web-UI (setze auf `false` zum Deaktivieren)

### Persistente Daten

Session-Daten, Reports, generierte Configs und ISOs werden im Docker Volume `nixify-data` gespeichert:

```bash
# Volume anzeigen
docker volume inspect nixify-data

# Daten löschen (wenn nötig)
cd nixos/modules/specialized/nixify/web-service/docker
docker-compose -f docker-compose.traefik.yml down -v
```
