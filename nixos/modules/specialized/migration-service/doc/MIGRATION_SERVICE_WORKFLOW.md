# Migration Service - Workflow & Architektur

## Übersicht: Wie funktioniert das Modul?

Dieses Dokument erklärt den **kompletten Workflow** des Migration-Service-Moduls.

---

## 1. Modul-Aktivierung

### In der Config aktivieren

```nix
# nixos/configs/modules/specialized/migration-service/config.nix
{
  modules.specialized.migration-service = {
    enable = true;
    
    # Web-Service konfigurieren
    webService = {
      enable = true;
      port = 8080;
      host = "0.0.0.0";  # Oder nur localhost
    };
    
    # Snapshot-Scripts bereitstellen
    snapshot = {
      enable = true;
      # Scripts werden automatisch bereitgestellt
    };
  };
}
```

### Was passiert dann?

1. **Modul wird aktiviert**
   - Web-Service startet (systemd)
   - Snapshot-Scripts werden verfügbar
   - Mapping-Database wird geladen

2. **Web-Service läuft lokal**
   - Auf Port 8080 (oder konfiguriert)
   - Erreichbar unter `http://localhost:8080`
   - Oder: `http://deine-ip:8080` (wenn host = "0.0.0.0")

3. **Snapshot-Scripts werden bereitgestellt**
   - Windows: `migration-snapshot-windows.ps1`
   - macOS: `migration-snapshot-macos.sh`
   - Download über Web-Service oder lokal verfügbar

---

## 2. Der komplette Workflow

### Phase 1: Windows/macOS User

```
┌─────────────────────────────────────────────────────────┐
│  Windows/macOS User                                      │
│                                                          │
│  1. Lädt Snapshot-Script herunter                       │
│     → Von Web-Service: http://deine-ip:8080/snapshot    │
│     → Oder: Lokal von NixOS-System                      │
│                                                          │
│  2. Führt Script aus                                    │
│     Windows: powershell migration-snapshot.ps1           │
│     macOS:    ./migration-snapshot.sh                   │
│                                                          │
│  3. Script analysiert System                            │
│     → Installierte Programme                            │
│     → System-Einstellungen                              │
│     → Hardware-Info                                     │
│                                                          │
│  4. Generiert Report (JSON)                            │
│     → nixos-migration-report.json                       │
│                                                          │
│  5. User kann Report reviewen                           │
│     → CLI/TUI Interface                                 │
│     → Oder: Manuell in Editor                           │
└─────────────────────────────────────────────────────────┘
                          ↓
                    Upload zum Server
                          ↓
┌─────────────────────────────────────────────────────────┐
│  NixOS System (mit aktiviertem Modul)                   │
│                                                          │
│  Web-Service empfängt Report                            │
│  → POST /api/v1/snapshot/upload                        │
│                                                          │
│  Server verarbeitet Report:                             │
│  1. Parst JSON-Report                                   │
│  2. Mappt Programme zu NixOS-Modulen                   │
│     → Nutzt mapping-database.json                       │
│  3. Generiert system-config.nix                        │
│     → Nutzt bestehende Module-APIs                      │
│     → module-manager API                                │
│     → system-manager API                                │
│  4. Validiert Config                                    │
│  5. Bietet Download an:                                 │
│     → Config-Dateien (ZIP)                              │
│     → Oder: Custom ISO-Image                            │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Detaillierte Architektur

### 3.1 Modul-Struktur

```
nixos/modules/specialized/migration-service/
├── default.nix                    # Modul-Entry
├── options.nix                    # Config-Optionen
├── config.nix                     # System-Integration
├── commands.nix                   # CLI-Commands
│
├── snapshot/                      # Snapshot-Scripts
│   ├── windows/
│   │   └── migration-snapshot.ps1  # Wird bereitgestellt
│   └── macos/
│       └── migration-snapshot.sh  # Wird bereitgestellt
│
├── mapping/                       # Programm-Mapping
│   ├── mapping-database.json      # Statische Mapping-DB
│   └── mapper.nix                 # Nix-Mapper-Logic
│
├── web-service/                   # Web-Service
│   ├── api/
│   │   └── main.go                # Go REST API
│   ├── config-generator/
│   │   └── generator.nix           # Config-Generator
│   └── handlers/
│       └── snapshot-handler.go     # Snapshot-Verarbeitung
│
└── iso-builder/                   # ISO-Builder
    └── iso-builder.nix             # ISO-Generierung
```

### 3.2 Was passiert bei `enable = true`?

**In `config.nix`:**

```nix
{ config, lib, pkgs, getModuleApi, ... }:

let
  cfg = getModuleConfig "migration-service";
  moduleManager = getModuleApi "module-manager";
  systemManager = getModuleApi "system-manager";
in
{
  # Web-Service als systemd-Service
  systemd.services.migration-web-service = lib.mkIf cfg.webService.enable {
    enable = true;
    serviceConfig = {
      ExecStart = "${webService}/bin/migration-web-service";
      Restart = "always";
    };
    environment = {
      PORT = toString cfg.webService.port;
      HOST = cfg.webService.host;
    };
  };
  
  # Snapshot-Scripts bereitstellen
  environment.systemPackages = lib.mkIf cfg.snapshot.enable [
    snapshotScripts.windows
    snapshotScripts.macos
  ];
  
  # Web-Service stellt Scripts auch über HTTP bereit
  # → http://localhost:8080/snapshot/windows
  # → http://localhost:8080/snapshot/macos
}
```

### 3.3 Web-Service Endpoints

**Bereitgestellte Endpoints:**

```
GET  /snapshot/windows          # Download Windows-Script
GET  /snapshot/macos            # Download macOS-Script

POST /api/v1/snapshot/upload   # Upload Snapshot-Report
GET  /api/v1/config/{session}   # Generierte Config abrufen
POST /api/v1/config/{session}/review  # Config anpassen
GET  /api/v1/config/{session}/download  # Config-Download
POST /api/v1/iso/build          # ISO bauen
GET  /api/v1/iso/{session}/download  # ISO-Download
```

---

## 4. Konkreter Workflow-Beispiel

### Schritt 1: Modul aktivieren

```nix
# In deiner Config
modules.specialized.migration-service = {
  enable = true;
  webService = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";  # Erreichbar von außen
  };
};
```

**Nach Rebuild:**
```bash
# Web-Service läuft
systemctl status migration-web-service
# → Active: running

# Erreichbar unter:
curl http://localhost:8080/api/v1/health
# → {"status": "ok"}
```

### Schritt 2: Windows-User lädt Script

```bash
# Windows-User (auf Windows-Maschine):
# Option A: Von Web-Service
curl http://deine-nixos-ip:8080/snapshot/windows -o migration-snapshot.ps1

# Option B: Direkt von NixOS-System (wenn lokal)
scp user@nixos-system:/nix/store/.../migration-snapshot.ps1 .
```

### Schritt 3: Script ausführen

```powershell
# Windows-User führt aus:
powershell -ExecutionPolicy Bypass -File migration-snapshot.ps1

# Output:
# ✅ Analysiere installierte Programme...
# ✅ Erfasse System-Einstellungen...
# ✅ Generiere Report...
# 
# 📋 Gefundene Programme:
#   - Visual Studio Code
#   - Firefox
#   - Steam
# 
# 📄 Report: nixos-migration-report.json
# 
# Möchten Sie den Report jetzt hochladen? (J/N)
```

### Schritt 4: Upload zum Server

```bash
# Windows-User lädt Report hoch:
curl -X POST http://deine-nixos-ip:8080/api/v1/snapshot/upload \
  -H "Content-Type: application/json" \
  -d @nixos-migration-report.json

# Response:
{
  "session_id": "abc123",
  "status": "processing",
  "estimated_time": "2-5 minutes"
}
```

### Schritt 5: Server verarbeitet

**Auf dem NixOS-System:**

```nix
# Web-Service nutzt:
let
  moduleManager = getModuleApi "module-manager";
  systemManager = getModuleApi "system-manager";
in
{
  # 1. Parse Report
  report = parseSnapshotReport uploadedReport;
  
  # 2. Mappe Programme zu Modulen
  mappedModules = mapProgramsToModules report.programs;
  
  # 3. Generiere Config
  generatedConfig = generateSystemConfig {
    inherit report mappedModules;
    moduleManager = moduleManager;
    systemManager = systemManager;
  };
  
  # 4. Validiere
  validatedConfig = validateConfig generatedConfig;
}
```

### Schritt 6: Config abrufen

```bash
# Windows-User ruft Config ab:
curl http://deine-nixos-ip:8080/api/v1/config/abc123

# Response:
{
  "config": "{ systemType = \"desktop\"; ... }",
  "preview": {
    "packages": ["firefox", "vscode", "steam"],
    "modules": ["modules.infrastructure.homelab-manager"],
    "desktop": "plasma"
  }
}
```

### Schritt 7: ISO bauen (optional)

```bash
# Windows-User baut ISO:
curl -X POST http://deine-nixos-ip:8080/api/v1/iso/build \
  -H "Content-Type: application/json" \
  -d '{"session_id": "abc123", "variant": "plasma5"}'

# Server baut ISO (kann 10-30 Minuten dauern)
# Response:
{
  "iso_url": "http://deine-nixos-ip:8080/api/v1/iso/abc123/download",
  "size": 2147483648,
  "checksum": "sha256:..."
}
```

---

## 5. Lokaler vs. Remote-Service

### Option A: Lokaler Service (localhost)

```nix
webService = {
  enable = true;
  port = 8080;
  host = "127.0.0.1";  # Nur localhost
};
```

**Use-Case:**
- Du hostest den Service auf deinem eigenen System
- Windows/macOS-User im gleichen Netzwerk
- Oder: Du testest lokal

**Zugriff:**
- Von NixOS-System: `http://localhost:8080`
- Von Windows/macOS: `http://nixos-system-ip:8080` (wenn im Netzwerk)

### Option B: Remote-Service (öffentlich)

```nix
webService = {
  enable = true;
  port = 8080;
  host = "0.0.0.0";  # Alle Interfaces
};
```

**Use-Case:**
- Öffentlicher Service
- Viele User
- Cloud-Deployment

**Zugriff:**
- Von überall: `http://deine-domain:8080`
- Oder: `https://migration.nixos.example.com`

### Option C: Separates Deployment

**Web-Service kann auch separat deployed werden:**
- Docker-Container
- Separate NixOS-Maschine
- Cloud-Service (AWS, etc.)

**Aber:** Code bleibt im Modul, nur Deployment ist separat.

---

## 6. Wie nutzt der Service bestehende Module?

### Beispiel: Config-Generierung

```nix
# In web-service/config-generator/generator.nix
{ snapshotReport, getModuleApi, ... }:

let
  # Nutze bestehende Module-APIs!
  moduleManager = getModuleApi "module-manager";
  systemManager = getModuleApi "system-manager";
  
  # Parse Report
  report = builtins.fromJSON (builtins.readFile snapshotReport);
  
  # Mappe Programme zu Modulen
  mappedModules = map (program:
    # Nutze module-manager API
    moduleManager.findModuleForProgram program.name
  ) report.programs;
  
  # Generiere Config
  generatedConfig = {
    systemType = "desktop";
    
    # Nutze system-manager API
    system = systemManager.getDefaultSystemConfig;
    
    # Module aktivieren
    modules = mappedModules;
    
    # Packages
    packages = extractPackages report.programs;
  };
in
generatedConfig
```

**Vorteil:**
- ✅ Nutzt bestehende Logik
- ✅ Keine Code-Duplikation
- ✅ Konsistente Config-Generierung

---

## 7. Zusammenfassung

### ✅ So funktioniert's:

1. **Modul aktivieren** in Config
   ```nix
   modules.specialized.migration-service.enable = true;
   ```

2. **Web-Service startet** automatisch
   - Läuft auf Port 8080 (oder konfiguriert)
   - Stellt Snapshot-Scripts bereit
   - Bietet API-Endpoints

3. **Windows/macOS-User:**
   - Lädt Snapshot-Script herunter
   - Führt aus → generiert Report
   - Lädt Report hoch

4. **Server verarbeitet:**
   - Nutzt bestehende Module-APIs
   - Generiert system-config.nix
   - Bietet Download an

5. **User erhält:**
   - Config-Dateien (ZIP)
   - Oder: Custom ISO-Image

### 🎯 Vorteile dieser Architektur:

- ✅ **Nutzt bestehende Module** (keine Duplikation)
- ✅ **Lokaler Service möglich** (auf deinem System)
- ✅ **Remote-Service möglich** (öffentlich)
- ✅ **Flexibles Deployment** (Docker, Cloud, etc.)
- ✅ **Einheitliche Architektur** (folgt Modul-Pattern)

---

**Das Modul ist also:**
- **Code im Repo** (nutzt Module-APIs)
- **Service läuft lokal** (oder remote)
- **Scripts werden bereitgestellt** (über Web-Service)
- **Config wird generiert** (nutzt bestehende Module)

**Perfekt für dein Ziel: "Free all users from Microsoft and Apple"!** 🚀
