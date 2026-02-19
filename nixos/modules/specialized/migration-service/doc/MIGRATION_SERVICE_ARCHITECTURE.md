# Migration Service Architecture - Windows/macOS → NixOS

## Vision: "Free all users from Microsoft and Apple" 🚀

Dieses Dokument beschreibt die Architektur für einen **kompletten Migrations-Service**, der Windows/macOS-Nutzer nahtlos zu NixOS migriert.

---

## 1. Übersicht: Der komplette Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: Snapshot (Windows/macOS)                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ User führt Snapshot-Script aus                       │  │
│  │ → Analysiert installierte Programme                 │  │
│  │ → Erfasst System-Einstellungen                      │  │
│  │ → Generiert Report (JSON)                           │  │
│  │ → User kann reviewen/anpassen                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Report wird zum Web-Service geschickt                │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: Web-Service (Server)                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Empfängt Snapshot-Report                              │  │
│  │ → Mappt Programme zu NixOS-Modulen                   │  │
│  │ → Generiert modulare system-config.nix               │  │
│  │ → Validiert Config                                    │  │
│  │ → Bietet Download-Optionen:                          │  │
│  │   • Config-Dateien (für bestehende NixOS-Install)   │  │
│  │   • Custom ISO-Image (mit eingebetteter Config)      │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: Installation (NixOS)                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ User bootet Custom ISO                                │  │
│  │ → Automatische Installation mit Config               │  │
│  │ → Oder: Manuelle Installation + Config-Import         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Komponenten-Architektur

### 2.1 Snapshot-Script (Windows/macOS)

**Zweck:** System-Analyse auf Windows/macOS

**Technologie:**
- **Windows:** PowerShell Script
- **macOS:** Shell Script (bash/zsh)

**Erfasst:**
1. **Installierte Programme**
   - Windows: Registry, Program Files, AppData
   - macOS: Applications, Homebrew, App Store
   
2. **System-Einstellungen**
   - Desktop-Environment-Präferenzen
   - Netzwerk-Einstellungen
   - Hardware-Info (CPU, GPU, RAM, etc.)
   - Keyboard-Layout
   - Timezone
   - Locale

3. **User-Präferenzen**
   - Browser-Präferenzen
   - Editor-Präferenzen
   - Development-Tools

**Output:** JSON-Report

### 2.2 Web-Service (Server)

**Zweck:** Config-Generierung und ISO-Build

**Komponenten:**
1. **REST API** (Go/Python)
2. **Programm-zu-Modul-Mapper**
3. **Config-Generator** (Nix)
4. **ISO-Builder** (NixOS)
5. **Database** (Config-Versionen, User-Sessions)

**Features:**
- Snapshot-Report empfangen
- Programm-Mapping zu NixOS-Modulen
- system-config.nix generieren
- ISO-Image mit Config bauen
- Download-Bereitstellung

### 2.3 Custom ISO-Image

**Zweck:** Automatische Installation mit Config

**Features:**
- Eingebettete system-config.nix
- Automatische Installation
- Oder: Manueller Installer mit Config-Import

---

## 3. Detaillierte Komponenten

### 3.1 Snapshot-Script (Windows)

**Datei:** `migration-snapshot-windows.ps1`

```powershell
# Windows Snapshot Script
# Erfasst installierte Programme und System-Einstellungen

$report = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    os = "windows"
    version = (Get-CimInstance Win32_OperatingSystem).Version
    hardware = @{
        cpu = (Get-CimInstance Win32_Processor).Name
        ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
        gpu = (Get-CimInstance Win32_VideoController).Name
    }
    programs = @()
    settings = @{}
}

# Installierte Programme erfassen
# Windows Registry
$programs = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" |
    Where-Object { $_.DisplayName } |
    Select-Object DisplayName, DisplayVersion, Publisher

# Program Files
$programFiles = Get-ChildItem "C:\Program Files" -Directory |
    Select-Object Name

# AppData (User-Programme)
$appData = Get-ChildItem "$env:APPDATA" -Directory |
    Select-Object Name

# System-Einstellungen
$report.settings = @{
    timezone = (Get-TimeZone).Id
    locale = (Get-Culture).Name
    keyboard = (Get-WinUserLanguageList).InputMethodTips
    desktop = "windows"  # Windows Desktop
}

# JSON-Report generieren
$report | ConvertTo-Json -Depth 10 | Out-File "nixos-migration-report.json"
```

**Output-Format:**
```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "os": "windows",
  "version": "10.0.19045",
  "hardware": {
    "cpu": "Intel Core i7-12700K",
    "ram": 34359738368,
    "gpu": "NVIDIA GeForce RTX 3080"
  },
  "programs": [
    {
      "name": "Visual Studio Code",
      "version": "1.85.0",
      "publisher": "Microsoft Corporation",
      "source": "registry"
    },
    {
      "name": "Firefox",
      "version": "121.0",
      "publisher": "Mozilla",
      "source": "programfiles"
    }
  ],
  "settings": {
    "timezone": "Europe/Berlin",
    "locale": "de-DE",
    "keyboard": "de-DE",
    "desktop": "windows"
  }
}
```

### 3.2 Snapshot-Script (macOS)

**Datei:** `migration-snapshot-macos.sh`

```bash
#!/bin/bash
# macOS Snapshot Script

report_file="nixos-migration-report.json"

# Hardware-Info
cpu=$(sysctl -n machdep.cpu.brand_string)
ram=$(sysctl -n hw.memsize)
gpu=$(system_profiler SPDisplaysDataType | grep "Chipset Model" | head -1 | cut -d: -f2 | xargs)

# Installierte Programme
programs=()

# Applications
for app in /Applications/*.app; do
    name=$(basename "$app" .app)
    version=$(defaults read "$app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
    programs+=("{\"name\":\"$name\",\"version\":\"$version\",\"source\":\"applications\"}")
done

# Homebrew
if command -v brew &> /dev/null; then
    brew list --formula | while read pkg; do
        programs+=("{\"name\":\"$pkg\",\"source\":\"homebrew\"}")
    done
fi

# System-Einstellungen
timezone=$(systemsetup -gettimezone | cut -d: -f2 | xargs)
locale=$(defaults read -g AppleLocale)

# JSON-Report generieren
cat > "$report_file" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "os": "macos",
  "version": "$(sw_vers -productVersion)",
  "hardware": {
    "cpu": "$cpu",
    "ram": $ram,
    "gpu": "$gpu"
  },
  "programs": [$(IFS=,; echo "${programs[*]}")],
  "settings": {
    "timezone": "$timezone",
    "locale": "$locale",
    "desktop": "macos"
  }
}
EOF
```

### 3.3 Programm-zu-Modul-Mapper

**Zweck:** Windows/macOS-Programme → NixOS-Module mappen

**Datei:** `migration-service/mapping-database.json`

```json
{
  "programs": {
    "Visual Studio Code": {
      "nixos_package": "vscode",
      "module": null,
      "category": "development"
    },
    "Firefox": {
      "nixos_package": "firefox",
      "module": null,
      "category": "browser"
    },
    "Docker Desktop": {
      "nixos_package": null,
      "module": "modules.infrastructure.homelab-manager",
      "category": "infrastructure"
    },
    "Steam": {
      "nixos_package": "steam",
      "module": null,
      "category": "gaming"
    },
    "Discord": {
      "nixos_package": "discord",
      "module": null,
      "category": "communication"
    }
  },
  "desktop_mapping": {
    "windows": {
      "preferred_de": "plasma",
      "reason": "Most similar to Windows UI"
    },
    "macos": {
      "preferred_de": "gnome",
      "reason": "Most similar to macOS UI"
    }
  }
}
```

### 3.4 Config-Generator

**Zweck:** system-config.nix aus Snapshot-Report generieren

**Datei:** `migration-service/config-generator.nix`

```nix
# Config Generator für Migration-Service
{ snapshotReport, mappingDatabase }:

let
  # Parse Snapshot-Report
  report = builtins.fromJSON (builtins.readFile snapshotReport);
  mapping = builtins.fromJSON (builtins.readFile mappingDatabase);
  
  # Programme zu Packages/Modulen mappen
  mappedPrograms = builtins.map (program:
    mapping.programs.${program.name} or null
  ) report.programs;
  
  # Packages extrahieren
  packages = builtins.filter (p: p != null && p.nixos_package != null) mappedPrograms;
  packageNames = builtins.map (p: p.nixos_package) packages;
  
  # Module extrahieren
  modules = builtins.filter (p: p != null && p.module != null) mappedPrograms;
  moduleNames = builtins.map (p: p.module) modules;
  
  # Desktop-Environment basierend auf OS
  desktopEnv = mapping.desktop_mapping.${report.os}.preferred_de;
  
in
{
  # System-Identität
  systemType = "desktop";
  hostName = "migrated-system";
  
  # System-Version
  system = {
    channel = "stable";
    bootloader = "systemd-boot";
  };
  
  # Desktop-Environment
  desktop = {
    enable = true;
    environment = desktopEnv;  # plasma oder gnome
  };
  
  # Packages
  packages = packageNames;
  
  # Module
  modules = moduleNames;
  
  # System-Einstellungen
  timeZone = report.settings.timezone;
  locale = report.settings.locale;
  
  # Hardware (wird später erkannt)
  hardware = {
    cpu = null;  # Wird bei Installation erkannt
    gpu = null;  # Wird bei Installation erkannt
  };
}
```

### 3.5 Web-Service API

**Architektur:** REST API (Go empfohlen, passt zu TUI-Engine)

**Endpoints:**

```
POST /api/v1/snapshot/upload
  → Empfängt Snapshot-Report
  → Gibt Session-ID zurück

GET /api/v1/config/{session_id}
  → Generiert system-config.nix
  → Gibt Config zurück

POST /api/v1/config/{session_id}/review
  → User kann Config anpassen
  → Speichert angepasste Config

GET /api/v1/config/{session_id}/download
  → Download als ZIP (configs/)
  → Oder: Custom ISO-Image

POST /api/v1/iso/build
  → Baut Custom ISO mit Config
  → Gibt Download-Link zurück
```

**Beispiel-Request:**

```bash
# 1. Snapshot hochladen
curl -X POST https://nixos-migration.example.com/api/v1/snapshot/upload \
  -H "Content-Type: application/json" \
  -d @nixos-migration-report.json

# Response:
{
  "session_id": "abc123",
  "status": "received",
  "estimated_time": "2-5 minutes"
}

# 2. Config generieren
curl https://nixos-migration.example.com/api/v1/config/abc123

# Response:
{
  "config": "{ systemType = \"desktop\"; ... }",
  "preview": {
    "packages": ["firefox", "vscode", "steam"],
    "modules": ["modules.infrastructure.homelab-manager"],
    "desktop": "plasma"
  }
}

# 3. ISO bauen
curl -X POST https://nixos-migration.example.com/api/v1/iso/build \
  -H "Content-Type: application/json" \
  -d '{"session_id": "abc123", "variant": "plasma5"}'

# Response:
{
  "iso_url": "https://nixos-migration.example.com/downloads/abc123/nixos-custom.iso",
  "size": 2147483648,
  "checksum": "sha256:..."
}
```

### 3.6 ISO-Builder

**Zweck:** Custom ISO-Image mit eingebetteter Config bauen

**Datei:** `migration-service/iso-builder.nix`

```nix
# Custom ISO Builder mit eingebetteter Config
{ pkgs, systemConfig, ... }:

let
  # Standard NixOS ISO
  baseIso = pkgs.nixos {
    imports = [
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    ];
  };
  
  # Custom Config einbetten
  customConfig = pkgs.writeText "system-config.nix" (builtins.readFile systemConfig);
  
  # Installer-Script anpassen
  installerScript = pkgs.writeScript "auto-install.sh" ''
    #!/bin/bash
    # Automatische Installation mit Config
    
    # Config kopieren
    cp /mnt/cdrom/system-config.nix /mnt/etc/nixos/
    
    # Installation starten
    nixos-install --system-config /mnt/etc/nixos/system-config.nix
  '';
  
in
pkgs.isoImage.installer {
  name = "nixos-custom";
  baseIso = baseIso;
  extraFiles = {
    "system-config.nix" = customConfig;
    "auto-install.sh" = installerScript;
  };
}
```

---

## 4. Implementierungs-Plan

### Phase 1: Snapshot-Script (2-3 Wochen)

**Aufgaben:**
1. ✅ Windows PowerShell Script
2. ✅ macOS Shell Script
3. ✅ Programm-Erkennung
4. ✅ System-Einstellungen erfassen
5. ✅ JSON-Report generieren
6. ✅ User-Review-Interface (CLI/TUI)

**Deliverables:**
- `migration-snapshot-windows.ps1`
- `migration-snapshot-macos.sh`
- Dokumentation

### Phase 2: Mapping-Database (1-2 Wochen)

**Aufgaben:**
1. ✅ Programm-zu-Package-Mapping
2. ✅ Programm-zu-Modul-Mapping
3. ✅ Desktop-Environment-Mapping
4. ✅ Kategorisierung

**Deliverables:**
- `mapping-database.json`
- Mapping-Tools
- Validation

### Phase 3: Web-Service (4-6 Wochen)

**Aufgaben:**
1. ✅ REST API (Go)
2. ✅ Snapshot-Upload
3. ✅ Config-Generator
4. ✅ Config-Review-Interface
5. ✅ ISO-Builder-Integration
6. ✅ Download-System

**Deliverables:**
- Web-Service
- API-Dokumentation
- Deployment-Scripts

### Phase 4: ISO-Builder (2-3 Wochen)

**Aufgaben:**
1. ✅ Custom ISO mit Config
2. ✅ Automatische Installation
3. ✅ Installer-Integration
4. ✅ Testing

**Deliverables:**
- ISO-Builder
- Installer-Scripts
- Testing-Suite

### Phase 5: Integration & Testing (2-3 Wochen)

**Aufgaben:**
1. ✅ End-to-End-Testing
2. ✅ Performance-Optimierung
3. ✅ Security-Audit
4. ✅ Dokumentation

**Deliverables:**
- Komplettes System
- Dokumentation
- Deployment-Guide

---

## 5. Technische Details

### 5.1 Programm-Erkennung (Windows)

**Quellen:**
- Windows Registry (`HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*`)
- Program Files (`C:\Program Files`, `C:\Program Files (x86)`)
- AppData (`%APPDATA%`, `%LOCALAPPDATA%`)
- Windows Store Apps
- Chocolatey Packages
- Scoop Packages

### 5.2 Programm-Erkennung (macOS)

**Quellen:**
- Applications (`/Applications`)
- Homebrew (`brew list`)
- Mac App Store
- User Applications (`~/Applications`)

### 5.3 Config-Generierung

**Schritte:**
1. Snapshot-Report parsen
2. Programme zu Packages/Modulen mappen
3. system-config.nix generieren
4. Validierung
5. Preview generieren

### 5.4 ISO-Build

**Schritte:**
1. Standard NixOS ISO als Base
2. system-config.nix einbetten
3. Auto-Installer-Script hinzufügen
4. ISO bauen
5. Checksum generieren

---

## 6. Security & Privacy

### 6.1 Datenschutz

**Wichtig:**
- Snapshot-Reports enthalten **keine persönlichen Daten**
- Nur Programm-Namen, keine Dateien
- User kann Report vor Upload reviewen
- Optionale Anonymisierung

### 6.2 Security

**Maßnahmen:**
- HTTPS für alle API-Calls
- Session-basierte Authentifizierung
- Rate-Limiting
- Input-Validation
- ISO-Checksum-Verification

---

## 7. User-Experience

### 7.1 Snapshot-Phase

**Workflow:**
1. User lädt Snapshot-Script herunter
2. Script ausführen (ein Klick)
3. Report wird generiert
4. User kann reviewen/anpassen
5. Upload zum Server

**UI:**
- CLI/TUI für Review
- Oder: Web-Interface (optional)

### 7.2 Config-Review

**Workflow:**
1. Server generiert Config
2. User kann Preview sehen
3. User kann anpassen
4. Config wird validiert
5. Download-Optionen

**UI:**
- Web-Interface (empfohlen)
- Oder: CLI-Tool

### 7.3 Installation

**Workflow:**
1. Custom ISO herunterladen
2. ISO auf USB brennen
3. Boot von USB
4. Automatische Installation mit Config
5. Fertig! 🎉

---

## 8. Beispiel-Workflow

### Schritt 1: Snapshot (Windows)

```powershell
# User führt aus:
.\migration-snapshot-windows.ps1

# Output:
# ✅ Analysiere installierte Programme...
# ✅ Erfasse System-Einstellungen...
# ✅ Generiere Report...
# 
# 📋 Gefundene Programme:
#   - Visual Studio Code
#   - Firefox
#   - Steam
#   - Docker Desktop
# 
# ⚙️  System-Einstellungen:
#   - Timezone: Europe/Berlin
#   - Locale: de-DE
#   - Desktop: Windows
# 
# 📄 Report gespeichert: nixos-migration-report.json
# 
# Möchten Sie den Report jetzt hochladen? (J/N)
```

### Schritt 2: Upload & Config-Generierung

```bash
# User lädt Report hoch
curl -X POST https://nixos-migration.example.com/api/v1/snapshot/upload \
  -d @nixos-migration-report.json

# Server generiert Config
# User erhält Preview:
{
  "preview": {
    "packages": ["firefox", "vscode", "steam"],
    "modules": ["modules.infrastructure.homelab-manager"],
    "desktop": "plasma",
    "timezone": "Europe/Berlin"
  }
}

# User kann anpassen und dann ISO bauen
```

### Schritt 3: ISO-Download & Installation

```bash
# User lädt Custom ISO herunter
# ISO enthält:
#   - NixOS Installer
#   - system-config.nix (eingebettet)
#   - Auto-Installer-Script

# Installation:
# 1. Boot von USB
# 2. Automatische Installation startet
# 3. Config wird automatisch verwendet
# 4. Fertig! 🎉
```

---

## 9. Erweiterte Features (Future)

### 9.1 Cloud-Sync

- Config in Cloud speichern
- Multi-Device-Sync
- Versionierung

### 9.2 AI-Assistenz

- Intelligente Programm-Mapping
- Vorschläge basierend auf Nutzung
- Automatische Optimierung

### 9.3 Community-Mappings

- User können Mappings vorschlagen
- Community-Review
- Automatische Integration

---

## 10. Zusammenfassung

### ✅ Komplette Lösung

1. **Snapshot-Script** (Windows/macOS)
   - Analysiert System
   - Generiert Report
   - User-Review

2. **Web-Service**
   - Empfängt Report
   - Generiert Config
   - Baut Custom ISO

3. **Custom ISO**
   - Eingebettete Config
   - Automatische Installation
   - Nahtlose Migration

### 🎯 Ziel erreicht

**"Free all users from Microsoft and Apple"** 🚀

- Einfache Migration
- Automatische Config-Generierung
- Custom ISO mit Installation
- Keine manuelle Config nötig

### 📋 Next Steps

1. Snapshot-Script implementieren
2. Mapping-Database aufbauen
3. Web-Service entwickeln
4. ISO-Builder integrieren
5. Testing & Deployment

---

## 11. Technologie-Stack

### Snapshot-Script
- **Windows:** PowerShell
- **macOS:** Shell Script (bash/zsh)

### Web-Service
- **Backend:** Go (empfohlen, passt zu TUI-Engine)
- **Alternative:** Python (FastAPI)
- **Database:** PostgreSQL (Config-Versionen)
- **Storage:** S3/MinIO (ISO-Images)

### ISO-Builder
- **NixOS** (nixos-generate-config)
- **NixOS ISO Builder**
- **Custom Installer-Scripts**

### Frontend (Optional)
- **Web-Interface:** React/Vue
- **Config-Review:** Web-basiert

---

**Das ist ein großes Projekt, aber machbar!** 🚀

Die modulare Architektur deines NixOS Control Centers macht es perfekt für diesen Use-Case!
