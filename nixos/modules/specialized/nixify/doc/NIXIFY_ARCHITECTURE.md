# Nixify - System-DNA-Extractor → NixOS-Config-Generator

## Vision: "Free all users from Microsoft, Apple, and proprietary Linux distros" 🚀

**Nixify** extrahiert System-State von Windows/macOS/Linux und generiert daraus deklarative NixOS-Configs.

> **Wichtig:** Das Modul läuft auf NixOS. Die Snapshot-Scripts laufen auf den Ziel-Systemen (Windows/macOS/Linux).

---

## 1. Übersicht: Der komplette Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: Snapshot (Windows/macOS/Linux)                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ User führt Snapshot-Script aus                       │  │
│  │ → Analysiert installierte Programme                 │  │
│  │ → Erfasst System-Einstellungen                      │  │
│  │ → Generiert Report (JSON)                           │  │
│  │ → User kann reviewen/anpassen                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Report wird zum NixOS-Web-Service geschickt         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: Web-Service (NixOS-System)                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Empfängt Snapshot-Report                              │  │
│  │ → Mappt Programme zu NixOS-Modulen                   │  │
│  │ → Generiert configs/*.nix Dateien                    │  │
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

## 2. System-Trennung (Kritisch!)

### ⚠️ Wichtig: Zwei getrennte Systeme

#### 1️⃣ Ziel-System (Windows/macOS/Linux)

**Was hier passiert:**
- User lädt **Snapshot-Script** herunter (vom NixOS-Web-Service)
- Führt Script aus (standalone, kein `ncc` nötig!)
- Script analysiert System
- Generiert Report (JSON)
- Upload zum NixOS-System

**Kein `ncc` hier!** - Nur standalone Scripts.

#### 2️⃣ NixOS-System (mit aktiviertem Modul)

**Was hier passiert:**
- **Web-Service** läuft (systemd)
- Empfängt Reports von Ziel-Systemen
- Generiert **configs/*.nix** Dateien
- Baut **Custom ISO** (optional)

**Commands auf NixOS:**
```bash
ncc nixify service start    # Web-Service starten
ncc nixify service status   # Service-Status
ncc nixify list             # Sessions auflisten
ncc nixify download <id>    # Config/ISO herunterladen
```

**Siehe:** `ARCHITECTURE_CLARIFICATION.md` für detaillierte Erklärung.

---

## 3. Komponenten-Architektur

### 3.1 Snapshot-Scripts (Windows/macOS/Linux)

**Zweck:** System-Analyse auf Ziel-Systemen

**Technologie:**
- **Windows:** PowerShell Script
- **macOS:** Shell Script (bash/zsh)
- **Linux:** Shell Script (bash) **NEU**

**Erfasst:**
1. **Installierte Programme**
   - Windows: Registry, Program Files, AppData
   - macOS: Applications, Homebrew, App Store
   - Linux: Package Manager (apt, dnf, pacman, zypper), Flatpak, Snap
   
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

### 3.2 Web-Service (NixOS-System)

**Zweck:** Config-Generierung und ISO-Build

**Komponenten:**
1. **REST API** (Go empfohlen, passt zu TUI-Engine)
2. **Programm-zu-Modul-Mapper**
3. **Config-Generator** (Nix)
4. **ISO-Builder** (NixOS)
5. **Database** (Config-Versionen, User-Sessions)

**Features:**
- Snapshot-Report empfangen
- Programm-Mapping zu NixOS-Modulen
- configs/*.nix Dateien generieren
- ISO-Image mit Config bauen
- Download-Bereitstellung

### 3.3 Custom ISO-Image

**Zweck:** Automatische Installation mit Config

**Features:**
- Eingebettetes configs/ Verzeichnis
- Automatische Installation
- Oder: Manueller Installer mit Config-Import

---

## 4. Cross-Platform Support

### 4.1 Windows

**Script:** `snapshot/windows/nixify-scan.ps1`

**Erkennung:**
- Windows Registry (`HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*`)
- Program Files (`C:\Program Files`, `C:\Program Files (x86)`)
- AppData (`%APPDATA%`, `%LOCALAPPDATA%`)
- Windows Store Apps
- Chocolatey Packages
- Scoop Packages

### 4.2 macOS

**Script:** `snapshot/macos/nixify-scan.sh`

**Erkennung:**
- Applications (`/Applications`)
- Homebrew (`brew list`)
- Mac App Store
- User Applications (`~/Applications`)

### 4.3 Linux ✅ **NEU**

**Script:** `snapshot/linux/nixify-scan.sh`

**Erkennung:**
- **Distro-Erkennung:** `/etc/os-release`
- **Package Manager Detection:**
  - Ubuntu/Debian: `apt` (dpkg)
  - Fedora/RHEL: `dnf` (rpm)
  - Arch: `pacman`
  - openSUSE: `zypper`
  - NixOS: `nix` (für Replikation)
- **Flatpak:** `flatpak list`
- **Snap:** `snap list`
- **Service Manager:** systemd, openrc, etc.
- **Desktop Environment:** GNOME, KDE, XFCE, etc.

**Unterstützte Distros:**
- Ubuntu/Debian (apt)
- Fedora/RHEL (dnf)
- Arch (pacman)
- openSUSE (zypper)
- NixOS (Replikation)

---

## 5. Detaillierte Komponenten

### 5.1 Snapshot-Script (Windows)

**Datei:** `snapshot/windows/nixify-scan.ps1`

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
    desktop = "windows"
}

# JSON-Report generieren
$report | ConvertTo-Json -Depth 10 | Out-File "nixify-report.json"
```

### 5.2 Snapshot-Script (macOS)

**Datei:** `snapshot/macos/nixify-scan.sh`

```bash
#!/bin/bash
# macOS Snapshot Script

report_file="nixify-report.json"

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

### 5.3 Snapshot-Script (Linux) ✅ **NEU**

**Datei:** `snapshot/linux/nixify-scan.sh`

```bash
#!/bin/bash
# Linux Snapshot Script

report_file="nixify-report.json"

# Distro-Erkennung
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro_id="$ID"
    distro_version="$VERSION_ID"
else
    distro_id="unknown"
    distro_version="unknown"
fi

# Hardware-Info
cpu=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
ram=$(free -b | grep "Mem:" | awk '{print $2}')
gpu=$(lspci | grep -i vga | cut -d: -f3 | xargs)

# Package Manager Detection
package_manager="unknown"
if command -v apt &> /dev/null; then
    package_manager="apt"
    packages=$(dpkg-query -W -f='${Package}\n' | head -20)
elif command -v dnf &> /dev/null; then
    package_manager="dnf"
    packages=$(rpm -qa | head -20)
elif command -v pacman &> /dev/null; then
    package_manager="pacman"
    packages=$(pacman -Q | cut -d' ' -f1 | head -20)
elif command -v zypper &> /dev/null; then
    package_manager="zypper"
    packages=$(rpm -qa | head -20)
fi

# Flatpak
if command -v flatpak &> /dev/null; then
    flatpak_apps=$(flatpak list --app --columns=application | tail -n +2)
fi

# Desktop Environment
desktop_env="${XDG_CURRENT_DESKTOP:-unknown}"
if [ -z "$XDG_CURRENT_DESKTOP" ]; then
    desktop_env=$(echo "$XDG_DATA_DIRS" | grep -oE '(gnome|kde|xfce)' | head -1)
fi

# System-Einstellungen
timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || date +%Z)
locale=$(locale | grep LANG= | cut -d= -f2 | cut -d. -f1)

# JSON-Report generieren
cat > "$report_file" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "os": "linux",
  "distro": {
    "id": "$distro_id",
    "version": "$distro_version"
  },
  "hardware": {
    "cpu": "$cpu",
    "ram": $ram,
    "gpu": "$gpu"
  },
  "package_manager": "$package_manager",
  "programs": [
    $(echo "$packages" | while read pkg; do
        echo "    {\"name\":\"$pkg\",\"source\":\"$package_manager\"},"
    done | sed '$ s/,$//')
  ],
  "settings": {
    "timezone": "$timezone",
    "locale": "$locale",
    "desktop": "$desktop_env"
  }
}
EOF
```

### 5.4 Programm-zu-Modul-Mapper

**Zweck:** Windows/macOS/Linux-Programme → NixOS-Module mappen

**Datei:** `mapping/mapping-database.json`

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
    },
    "linux": {
      "gnome": {
        "preferred_de": "gnome",
        "reason": "Same desktop environment"
      },
      "kde": {
        "preferred_de": "plasma",
        "reason": "Same desktop environment"
      },
      "xfce": {
        "preferred_de": "xfce",
        "reason": "Same desktop environment"
      },
      "default": {
        "preferred_de": "plasma",
        "reason": "Most flexible and customizable"
      }
    }
  }
}
```

### 5.5 Config-Generator

**Zweck:** configs/*.nix Dateien aus Snapshot-Report generieren

**Datei:** `web-service/config-generator/generator.nix`

```nix
# Config Generator für Nixify
{ snapshotReport, mappingDatabase, getModuleApi }:

let
  # Parse Snapshot-Report
  report = builtins.fromJSON (builtins.readFile snapshotReport);
  mapping = builtins.fromJSON (builtins.readFile mappingDatabase);
  
  # Nutze bestehende Module-APIs
  moduleManager = getModuleApi "module-manager";
  systemManager = getModuleApi "system-manager";
  
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
  desktopEnv = if report.os == "linux" then
    (mapping.desktop_mapping.linux.${report.settings.desktop} or mapping.desktop_mapping.linux.default).preferred_de
  else
    mapping.desktop_mapping.${report.os}.preferred_de;
  
in
{
  # System-Identität
  systemType = "desktop";
  hostName = "nixified-system";
  
  # System-Version
  system = {
    channel = "stable";
    bootloader = "systemd-boot";
  };
  
  # Desktop-Environment
  desktop = {
    enable = true;
    environment = desktopEnv;
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

### 5.6 Web-Service API

**Architektur:** REST API (Go empfohlen, passt zu TUI-Engine)

**Endpoints:**

```
# Für Ziel-Systeme (Windows/macOS/Linux)
GET  /download/windows     # Download Windows-Script
GET  /download/macos       # Download macOS-Script
GET  /download/linux        # Download Linux-Script
POST /api/v1/upload         # Upload Report

# Für NixOS-System (Service-Management)
GET  /api/v1/health         # Service-Health
GET  /api/v1/sessions       # Alle Sessions
GET  /api/v1/session/{id}   # Session-Details
GET  /api/v1/config/{id}    # Generierte Config
POST /api/v1/iso/build      # ISO bauen
GET  /api/v1/iso/{id}       # ISO-Download
```

**Beispiel-Request:**

```bash
# 1. Snapshot hochladen (von Windows/macOS/Linux)
curl -X POST http://nixos-ip:8080/api/v1/upload \
  -H "Content-Type: application/json" \
  -d @nixify-report.json

# Response:
{
  "session_id": "abc123",
  "status": "processing",
  "estimated_time": "2-5 minutes"
}

# 2. Config abrufen (von NixOS-System)
curl http://localhost:8080/api/v1/config/abc123

# Response:
{
  "config": "{ systemType = \"desktop\"; ... }",
  "preview": {
    "packages": ["firefox", "vscode", "steam"],
    "modules": ["modules.infrastructure.homelab-manager"],
    "desktop": "plasma"
  }
}

# 3. ISO bauen (von NixOS-System)
curl -X POST http://localhost:8080/api/v1/iso/build \
  -H "Content-Type: application/json" \
  -d '{"session_id": "abc123", "variant": "plasma5"}'

# Response:
{
  "iso_url": "http://localhost:8080/api/v1/iso/abc123/download",
  "size": 2147483648,
  "checksum": "sha256:..."
}
```

### 5.7 ISO-Builder

**Zweck:** Custom ISO-Image mit eingebetteter Config bauen

**Datei:** `iso-builder/iso-builder.nix`

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
  # Configs-Verzeichnis erstellen
  configsDir = pkgs.runCommand "nixify-configs" {} ''
    mkdir -p $out/configs
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: content:
      "echo ${lib.escapeShellArg content} > $out/configs/${name}"
    ) sessionConfigs)}
  '';
  
  # Installer-Script anpassen
  installerScript = pkgs.writeScript "auto-install.sh" ''
    #!/bin/bash
    # Automatische Installation mit Configs
    
    # Configs kopieren
    mkdir -p /mnt/etc/nixos/configs
    cp -r /mnt/cdrom/configs/* /mnt/etc/nixos/configs/
    
    # Installation starten (configs werden automatisch von flake.nix geladen)
    nixos-install
  '';
  
in
pkgs.isoImage.installer {
  name = "nixos-nixified";
  baseIso = baseIso;
  extraFiles = {
    "configs" = configsDir;
    "auto-install.sh" = installerScript;
  };
}
```

---

## 6. Modul-Struktur

### 6.1 Verzeichnis-Struktur

```
nixos/modules/specialized/nixify/
├── default.nix                    # Modul-Entry-Point
├── options.nix                     # Config-Optionen
├── config.nix                      # System-Integration
├── commands.nix                    # CLI-Commands
├── README.md
├── CHANGELOG.md
│
├── snapshot/                       # Snapshot-Scripts
│   ├── windows/
│   │   └── nixify-scan.ps1
│   ├── macos/
│   │   └── nixify-scan.sh
│   └── linux/                      # NEU
│       └── nixify-scan.sh
│
├── mapping/                        # Programm-Mapping
│   ├── mapping-database.json
│   └── mapper.nix
│
├── web-service/                    # Web-Service
│   ├── api/
│   │   └── main.go
│   ├── config-generator/
│   │   └── generator.nix
│   └── handlers/
│       └── snapshot-handler.go
│
├── iso-builder/                    # ISO-Builder
│   └── iso-builder.nix
│
└── doc/                            # Dokumentation
    ├── NIXIFY_ARCHITECTURE.md      # Diese Datei
    ├── NIXIFY_WORKFLOW.md
    ├── ARCHITECTURE_CLARIFICATION.md
    └── ...
```

### 6.2 Config-Pfad

```nix
systemConfig.modules.specialized.nixify = {
  enable = true;
  webService = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";
  };
  snapshot = {
    enable = true;
  };
};
```

### 6.3 CLI-Commands (auf NixOS)

```bash
# Service-Management
ncc nixify service start    # Web-Service starten
ncc nixify service status   # Service-Status
ncc nixify service stop     # Service stoppen
ncc nixify service logs     # Service-Logs

# Session-Management
ncc nixify list             # Alle Sessions auflisten
ncc nixify show <session>   # Session-Details
ncc nixify download <id>    # Config/ISO herunterladen
```

---

## 7. Implementierungs-Plan

### Phase 1: Snapshot-Scripts (2-3 Wochen)

**Aufgaben:**
1. ✅ Windows PowerShell Script
2. ✅ macOS Shell Script
3. ✅ Linux Shell Script **NEU**
4. ✅ Programm-Erkennung
5. ✅ System-Einstellungen erfassen
6. ✅ JSON-Report generieren
7. ✅ User-Review-Interface (CLI/TUI)

**Deliverables:**
- `snapshot/windows/nixify-scan.ps1`
- `snapshot/macos/nixify-scan.sh`
- `snapshot/linux/nixify-scan.sh` **NEU**

### Phase 2: Mapping-Database (1-2 Wochen)

**Aufgaben:**
1. ✅ Programm-zu-Package-Mapping
2. ✅ Programm-zu-Modul-Mapping
3. ✅ Desktop-Environment-Mapping (inkl. Linux)
4. ✅ Kategorisierung

**Deliverables:**
- `mapping/mapping-database.json`
- `mapping/mapper.nix`
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

## 8. Security & Privacy

### 8.1 Datenschutz

**Wichtig:**
- Snapshot-Reports enthalten **keine persönlichen Daten**
- Nur Programm-Namen, keine Dateien
- User kann Report vor Upload reviewen
- Optionale Anonymisierung

### 8.2 Security

**Maßnahmen:**
- HTTPS für alle API-Calls
- Session-basierte Authentifizierung
- Rate-Limiting
- Input-Validation
- ISO-Checksum-Verification

---

## 9. Zusammenfassung

### ✅ Komplette Lösung

1. **Snapshot-Scripts** (Windows/macOS/Linux)
   - Analysiert System
   - Generiert Report
   - User-Review

2. **Web-Service** (NixOS)
   - Empfängt Report
   - Generiert Config
   - Baut Custom ISO

3. **Custom ISO**
   - Eingebettete Config
   - Automatische Installation
   - Nahtlose Migration

### 🎯 Ziel erreicht

**"Free all users from Microsoft, Apple, and proprietary Linux distros"** 🚀

- Einfache Migration
- Automatische Config-Generierung
- Custom ISO mit Installation
- Keine manuelle Config nötig
- Cross-platform Support (Windows, macOS, Linux)

### 📋 Next Steps

1. Snapshot-Scripts implementieren (inkl. Linux)
2. Mapping-Database aufbauen
3. Web-Service entwickeln
4. ISO-Builder integrieren
5. Testing & Deployment

---

## 10. Technologie-Stack

### Snapshot-Scripts
- **Windows:** PowerShell
- **macOS:** Shell Script (bash/zsh)
- **Linux:** Shell Script (bash) **NEU**

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
