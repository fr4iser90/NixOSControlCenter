# Architektur-Klarstellung - Nixify

## Das Problem: Verwirrung zwischen Systemen

**Frage:** Warum sollte man auf seinem NixOS-System `ncc nixify scan windows` machen?

**Antwort:** Das macht keinen Sinn! Die Architektur muss klar getrennt werden.

---

## Die richtige Architektur

### Zwei verschiedene Systeme

#### 1️⃣ Ziel-System (Windows/macOS/Linux)

**Was passiert hier:**
- User führt **Snapshot-Script** aus
- Script analysiert das System
- Generiert **Report (JSON)**
- Report wird zum **NixOS-System** geschickt

**Commands:**
```bash
# Auf Windows:
powershell -ExecutionPolicy Bypass -File nixify-scan.ps1

# Auf macOS:
./nixify-scan.sh

# Auf Linux:
./nixify-scan.sh
```

**Kein `ncc` hier!** - Das Script ist standalone.

#### 2️⃣ NixOS-System (mit aktiviertem Modul)

**Was passiert hier:**
- **Web-Service** läuft (systemd)
- Empfängt Reports von Ziel-Systemen
- Generiert **system-config.nix**
- Baut **Custom ISO** (optional)

**Commands:**
```bash
# Auf NixOS:
ncc nixify service start    # Web-Service starten
ncc nixify service status   # Service-Status
ncc nixify service stop     # Service stoppen
```

---

## Der komplette Workflow

### Phase 1: Auf Ziel-System (Windows/macOS/Linux)

```
┌─────────────────────────────────────────┐
│  Windows/macOS/Linux System             │
│                                          │
│  1. User lädt Snapshot-Script herunter  │
│     → Von Web-Service:                  │
│        http://nixos-system-ip:8080/download/windows
│        http://nixos-system-ip:8080/download/macos
│        http://nixos-system-ip:8080/download/linux
│                                          │
│  2. User führt Script aus               │
│     Windows: powershell nixify-scan.ps1  │
│     macOS:   ./nixify-scan.sh           │
│     Linux:   ./nixify-scan.sh           │
│                                          │
│  3. Script analysiert System            │
│     → Programme, Services, Settings      │
│                                          │
│  4. Generiert Report (JSON)             │
│     → nixify-report.json                │
│                                          │
│  5. User kann Report reviewen            │
│                                          │
│  6. Upload zum NixOS-System             │
│     → POST http://nixos-system-ip:8080/api/v1/upload
└─────────────────────────────────────────┘
```

### Phase 2: Auf NixOS-System

```
┌─────────────────────────────────────────┐
│  NixOS System (mit nixify Modul)        │
│                                          │
│  1. Web-Service läuft                   │
│     → systemd Service                    │
│     → Port 8080 (konfigurierbar)        │
│                                          │
│  2. Empfängt Report                     │
│     → POST /api/v1/upload               │
│                                          │
│  3. Verarbeitet Report                  │
│     → Mappt Programme zu NixOS-Modulen  │
│     → Generiert system-config.nix       │
│                                          │
│  4. Bietet Download an                 │
│     → Config-Dateien (ZIP)              │
│     → Oder: Custom ISO-Image            │
└─────────────────────────────────────────┘
```

---

## Commands - Richtig getrennt

### Auf NixOS-System (mit Modul)

```bash
# Service-Management
ncc nixify service start    # Web-Service starten
ncc nixify service status   # Service-Status anzeigen
ncc nixify service stop     # Service stoppen
ncc nixify service logs     # Service-Logs anzeigen

# Session-Management (optional)
ncc nixify list             # Alle Sessions auflisten
ncc nixify show <session>   # Session-Details anzeigen
ncc nixify download <session>  # Config/ISO herunterladen
```

### Auf Ziel-System (Windows/macOS/Linux)

**Kein `ncc` hier!** - Nur standalone Scripts:

```bash
# Windows
powershell -ExecutionPolicy Bypass -File nixify-scan.ps1

# macOS/Linux
./nixify-scan.sh
```

**Das Script:**
- Analysiert System
- Generiert Report
- Bietet Upload-Option an
- Oder: User lädt manuell hoch

---

## Web-Service Endpoints

### Für Ziel-Systeme (Windows/macOS/Linux)

```
GET  /download/windows     # Download Windows-Script
GET  /download/macos       # Download macOS-Script
GET  /download/linux        # Download Linux-Script
POST /api/v1/upload         # Upload Report
```

### Für NixOS-System (Service-Management)

```
GET  /api/v1/health         # Service-Health
GET  /api/v1/sessions       # Alle Sessions
GET  /api/v1/session/{id}   # Session-Details
GET  /api/v1/config/{id}    # Generierte Config
POST /api/v1/iso/build      # ISO bauen
GET  /api/v1/iso/{id}       # ISO-Download
```

---

## Was das Modul macht

### Auf NixOS-System

1. **Web-Service bereitstellen**
   - REST API für Report-Upload
   - Script-Download-Endpoints
   - Config-Generierung
   - ISO-Builder

2. **Snapshot-Scripts bereitstellen**
   - Windows-Script (PowerShell)
   - macOS-Script (Shell)
   - Linux-Script (Shell)
   - Über Web-Service downloadbar

3. **Config-Generierung**
   - Report parsen
   - Programme zu Modulen mappen
   - system-config.nix generieren

4. **ISO-Builder** (optional)
   - Custom ISO mit Config
   - Automatische Installation

### NICHT auf Ziel-Systemen

- ❌ Kein `ncc` auf Windows/macOS/Linux
- ❌ Keine NixOS-Dependencies
- ✅ Nur standalone Scripts

---

## Beispiel-Workflow

### Schritt 1: NixOS-System vorbereiten

```bash
# Auf NixOS-System
# Modul aktivieren in Config:
systemConfig.modules.specialized.nixify = {
  enable = true;
  webService = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";  # Erreichbar von außen
  };
};

# Rebuild
sudo nixos-rebuild switch

# Service starten
ncc nixify service start
```

### Schritt 2: Windows-System analysieren

```bash
# Auf Windows-System
# Script herunterladen
curl http://nixos-system-ip:8080/download/windows -o nixify-scan.ps1

# Script ausführen
powershell -ExecutionPolicy Bypass -File nixify-scan.ps1

# Script analysiert System → generiert nixify-report.json
# Script bietet Upload an:
# "Upload to NixOS system? (Y/N)"
# → Y: Upload zu http://nixos-system-ip:8080/api/v1/upload
```

### Schritt 3: NixOS-System verarbeitet

```bash
# Auf NixOS-System
# Service verarbeitet automatisch:
# → Report empfangen
# → Config generiert
# → Session-ID zurückgegeben

# User kann Config abrufen:
ncc nixify show abc123
ncc nixify download abc123
```

---

## Zusammenfassung

### ✅ Richtig

**Auf NixOS:**
- `ncc nixify service start` - Web-Service starten
- `ncc nixify service status` - Service-Status
- `ncc nixify list` - Sessions auflisten

**Auf Windows/macOS/Linux:**
- `./nixify-scan.ps1` oder `./nixify-scan.sh` - Standalone Script
- Kein `ncc` nötig!

### ❌ Falsch (was ich vorher gesagt habe)

- `ncc nixify scan windows` - Macht keinen Sinn!
- `ncc nixify scan linux` - Du bist ja auf NixOS!

---

## Klarstellung

**Das Modul läuft NUR auf NixOS!**

- ✅ Web-Service auf NixOS
- ✅ Scripts werden bereitgestellt (downloadbar)
- ✅ Config-Generierung auf NixOS
- ✅ ISO-Builder auf NixOS

**Die Snapshot-Scripts laufen auf Ziel-Systemen!**

- ✅ Windows-Script auf Windows
- ✅ macOS-Script auf macOS
- ✅ Linux-Script auf Linux
- ✅ Keine NixOS-Dependencies
- ✅ Standalone, portable

---

**Jetzt klar?** 🎯
