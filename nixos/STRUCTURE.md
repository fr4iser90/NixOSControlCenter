# NixOS Control Center - Strukturübersicht

## 📦 Core Module (IMMER geladen)

```
core/
├── boot/              # Bootloader (systemd-boot, GRUB, rEFInd)
├── hardware/          # CPU, GPU, Memory
├── network/           # NetworkManager, Firewall
├── system/            # Locale, Keymap
├── user/              # User Management, Roles, Shells
└── config/            # ⭐ Config Management System
    ├── config-schema.nix      # Schema Discovery & Version Management
    ├── config-detection.nix    # Version Detection
    ├── config-migration.nix    # Migration Engine
    ├── config-validator.nix    # Validation Engine
    └── config-check.nix        # Main Command (validate + migrate)
```

**Core/config/** = Generisches Config-Management (Schema, Migration, Validierung)

---

## 🎯 Features (Optional, aktivierbar)

### Basis-Features (keine Dependencies)
```
terminal-ui              # UI-System (API immer verfügbar)
system-config-manager    # Desktop-Config Management
bootentry-manager        # Boot-Entry Management
homelab-manager          # Homelab Management
vm-manager               # VM Management
ai-workspace             # AI Workspace
hackathon-manager        # Hackathon Management
```

### Abhängige Features
```
command-center          → terminal-ui
system-updater          → terminal-ui, command-center
system-checks           → terminal-ui
system-logger           → terminal-ui
ssh-client-manager      → terminal-ui
ssh-server-manager      → terminal-ui, command-center
system-discovery        → terminal-ui, command-center
```

---

## 🔧 Config-bezogene Systeme

### 1. **core/config/** (Core Module)
- **Zweck**: Generisches Config-Management
- **Funktionen**:
  - Schema Discovery (automatisch)
  - Version Detection
  - Migration (v1 → v2, etc.)
  - Validation
- **Keine Dependencies** (Core Module)
- **Wird von**: Niemand direkt verwendet (nur intern)

### 2. **system-config-manager** (Feature)
- **Zweck**: Desktop-Config Management
- **Funktionen**:
  - `update-desktop-config` - Desktop-Config bearbeiten
  - `update-features-config` - Features enable/disable
- **Dependencies**: KEINE
- **Wird von**: User direkt verwendet

### 3. **system-updater/config-migration.nix** (Feature)
- **Zweck**: Migration von alter Config-Struktur
- **Funktionen**:
  - Migriert alte `system-config.nix` → neue modulare Struktur
  - Erstellt `configs/*.nix` Dateien
- **Dependencies**: terminal-ui (für Output)
- **Wird von**: `system-updater` verwendet

### 4. **system-updater/feature-manager.nix** (Feature)
- **Zweck**: Feature Enable/Disable Management
- **Funktionen**:
  - `update-features-config` - Features aktivieren/deaktivieren
  - Liest Feature-Status aus `features-config.nix`
- **Dependencies**: terminal-ui, command-center
- **Wird von**: `system-updater` verwendet

---

## 📊 Dependency Graph

```
terminal-ui (Basis)
    ├── command-center
    │       ├── system-updater
    │       ├── ssh-server-manager
    │       └── system-discovery
    ├── system-checks
    ├── system-logger
    └── ssh-client-manager

system-config-manager (Standalone)
bootentry-manager (Standalone)
homelab-manager (Standalone)
vm-manager (Standalone)
ai-workspace (Standalone)
hackathon-manager (Standalone)
```

---

## 🤔 Optionen für Config-Initializer

### Option 1: Neues Feature `config-initializer`
**Pro:**
- Klare Trennung
- Kann von Features als Dependency verwendet werden
- Einfach zu erweitern

**Contra:**
- Neue Dependency für Features
- Mehr Features = mehr Komplexität

**Dependencies:**
- `terminal-ui` (für Output)
- Optional: `command-center` (für Commands)

---

### Option 2: Integration in `system-config-manager`
**Pro:**
- Bereits vorhanden
- Keine neue Dependency
- Logisch zusammen (Config-Management)

**Contra:**
- `system-config-manager` wird größer
- Möglicherweise zu viel Verantwortung

**Aktuell:**
- `system-config-manager` hat KEINE Dependencies
- Verwaltet nur Desktop-Config

**Erweiterung:**
- `system-config-manager` erweitern um:
  - Feature-Config Initialisierung
  - Generisches Config-Template-System

---

### Option 3: Integration in `core/config/`
**Pro:**
- Core Module = immer verfügbar
- Keine Feature-Dependency nötig
- Logisch (Config-Management)

**Contra:**
- Core Module sollten minimal sein
- Feature-spezifische Logik in Core?

**Aktuell:**
- `core/config/` = generisches Schema/Migration/Validation
- Keine Feature-spezifische Logik

---

### Option 4: Integration in `system-updater`
**Pro:**
- Bereits für Config-Management zuständig
- Hat bereits `config-migration.nix`
- Hat bereits `feature-manager.nix`

**Contra:**
- `system-updater` wird noch größer
- Initialisierung ≠ Update

**Aktuell:**
- `system-updater` = Updates, Migration, Feature-Management
- Dependencies: `terminal-ui`, `command-center`

---

## 💡 Empfehlung

### **Option 2: Integration in `system-config-manager`**

**Warum:**
1. ✅ Bereits vorhanden, keine neue Dependency
2. ✅ Logisch: Config-Management gehört zusammen
3. ✅ `system-config-manager` hat aktuell KEINE Dependencies
4. ✅ Kann erweitert werden ohne Breaking Changes

**Erweiterung:**
```nix
system-config-manager/
├── default.nix
├── desktop-manager.nix      # Bereits vorhanden
├── feature-manager.nix      # Bereits vorhanden (update-features-config)
└── config-initializer.nix   # NEU: Feature-Config Initialisierung
```

**Funktionen:**
- `init-feature-config <feature>` - Erstellt Config mit Defaults
- Automatisch beim ersten Aktivieren eines Features
- Generisches Template-System für alle Features

**Dependencies bleiben:**
- KEINE (wie bisher)

**Verwendung:**
- Features können `system-config-manager` als Dependency nutzen (optional)
- Oder: `system-config-manager` läuft automatisch beim Feature-Enable

---

## 📝 Zusammenfassung

**Aktuelle Config-Systeme:**
1. `core/config/` - Generisches Schema/Migration/Validation
2. `system-config-manager` - Desktop-Config Management
3. `system-updater/config-migration.nix` - Migration
4. `system-updater/feature-manager.nix` - Feature Enable/Disable

**Vorschlag:**
- Config-Initializer in `system-config-manager` integrieren
- Keine neue Dependency
- Logisch zusammen
- Einfach erweiterbar

