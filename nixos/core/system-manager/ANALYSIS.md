# System-Manager Analyse

## 📋 Übersicht: Was macht `system-manager`?

Der `system-manager` ist ein **Multi-Purpose Core-Modul**, das viele verschiedene Funktionen kombiniert. Er ist aktuell ein "Swiss Army Knife" für System-Management.

---

## 🔍 Detaillierte Funktionsanalyse

### 1. **System Configuration Update** (`handlers/system-update.nix`)
**Command**: `ncc system-update`

**Was macht es:**
- ✅ Updated die **komplette NixOS Config** aus Git (remote oder local)
- ✅ Unterstützt mehrere Branches (main, develop, experimental, custom)
- ✅ Erstellt Backups vor Updates (`/var/backup/nixos`)
- ✅ **NICHT**: Updated Custom-Configs (die bleiben unberührt)
- ✅ Validiert Config vor Update (`ncc-config-check`)
- ✅ Optional: Auto-Build nach Update
- ✅ Interaktive Branch-Auswahl

**Scope**: 
- Updated `/etc/nixos/` (Flake + alle Configs)
- **AUSSER**: Custom-Configs bleiben unberührt

---

### 2. **Feature Management** (`handlers/feature-manager.nix`)
**Command**: `ncc feature-manager`

**Was macht es:**
- ✅ Interaktives Feature-Toggling mit `fzf`
- ✅ Liest Feature-Status aus `features-config.nix`
- ✅ Updated `features-config.nix` (enable/disable Features)
- ✅ Zeigt aktuellen Status in Brackets: `feature-name [true/false]`
- ✅ Multi-Select Support (TAB/SPACE)
- ✅ Triggered System-Rebuild nach Änderungen

**Features managed:**
- system-logger, system-checks, system-config-manager
- system-discovery, ssh-client-manager, ssh-server-manager
- bootentry-manager, homelab-manager, vm-manager, ai-workspace

---

### 3. **Channel/Flake Update** (`handlers/channel-manager.nix`)
**Command**: `ncc update-channels`

**Was macht es:**
- ✅ Updated Flake Inputs (`nix flake update`)
- ✅ Rebuilded System nach Channel-Update
- ✅ Unterstützt `ncc build switch` (wenn system-checks enabled)
- ✅ Fallback auf `nixos-rebuild switch`

---

### 4. **Desktop Management** (`handlers/desktop-manager.nix`)
**Command**: `ncc desktop-manager [enable|disable]`

**Was macht es:**
- ✅ Enable/Disable Desktop Environment
- ✅ Updated `desktop-config.nix`
- ✅ Behält bestehende Settings (environment, display, theme, audio)
- ✅ Triggered System-Rebuild

**Helper Script**: `update-desktop-config` (internal)

---

### 5. **Module Version Checking** (`handlers/module-version-check.nix`)
**Commands**: 
- `ncc check-module-versions` (via `scripts/check-versions.nix`)
- `ncc update-modules` (via `scripts/smart-update.nix` - coming soon)

**Was macht es:**
- ✅ **Auto-Discovery**: Liest Module-Versionen aus `options.nix` (Core + Features)
- ✅ Vergleicht installierte vs. verfügbare Versionen (Core + Features)
- ✅ Findet Migration-Pfade (upgrade & downgrade)
- ✅ Unterstützt Core-Module (`systemConfig.*`) und Feature-Module (`features.*`)
- ✅ Zeigt Update-Status (current/auto/manual/unknown)
- ✅ Unterstützt Migration-Chains (z.B. 1.0 → 1.1 → 2.0)
- ✅ Smart Update mit automatischer Migration

**Version Sources:**
- **Installed**: Aus `config.features.*._version` (User Config)
- **Available**: Aus `features/*/options.nix` (Git/Code)
- **Stable**: Optional `stableVersion` in `options.nix`

---

### 6. **Feature Migration** (`handlers/feature-migration.nix`)
**Wird verwendet von**: `ncc update-features`

**Was macht es:**
- ✅ Führt Feature-Migrations aus (`migrations/vX-to-vY.nix`)
- ✅ Unterstützt Upgrade & Downgrade
- ✅ Migration-Chains (mehrere Schritte)
- ✅ Erstellt Backups vor Migration
- ✅ Option-Renamings, Type-Conversions, Migration-Scripts

---

### 7. **System Config Migration** (`config-migration.nix`)
**Command**: `ncc migrate-system-config` (via Command-Center)

**Was macht es:**
- ✅ Migriert alte `system-config.nix` → neue modulare Struktur
- ✅ Verschiebt Configs nach `configs/`:
  - `features` → `configs/features-config.nix`
  - `desktop` → `configs/desktop-config.nix`
  - `hardware` → `configs/hardware-config.nix`
  - `network` → `configs/network-config.nix`
  - `logging` → `configs/logging-config.nix`
- ✅ Erstellt Backups automatisch
- ✅ Prüft ob Migration bereits durchgeführt wurde
- ✅ Erkennt alte Struktur automatisch
- ✅ Behält alle bestehenden Werte

**Migration:**
- `system-config.nix` (monolithisch) → `configs/*.nix` (modular)
- Nur kritische Werte bleiben in `system-config.nix`

---

### 8. **System Config Validation** (`validators/config-validator.nix`)
**Command**: `ncc validate-system-config` (via Command-Center)

**Was macht es:**
- ✅ Validiert `system-config.nix` Struktur
- ✅ Prüft Nix-Syntax
- ✅ Prüft kritische Werte:
  - `systemType`, `hostName`, `system.channel`
  - `system.bootloader`, `allowUnfree`, `users`, `timeZone`
- ✅ Prüft ob modulare Struktur verwendet wird
- ✅ Prüft ob `configs/` existiert
- ✅ Zeigt Warnings bei alter Struktur
- ✅ Empfiehlt Migration wenn nötig
- ✅ Exit-Code: 0 (OK) oder 1 (Fehler/Warnungen)

---

### 9. **Homelab Utilities** (`lib/homelab-utils.nix`) ⚠️
**Command**: `ncc homelab-minimize`

**Was macht es:**
- ✅ Konvertiert Desktop-System → minimaler Homelab-Server
- ✅ Disabled Desktop Environment
- ✅ Enabled SSH Client & Server Manager
- ✅ Triggered System-Rebuild

**Problem**: 
- ❌ **Spezifisch für Homelab** - gehört nicht in `system-updater`
- ❌ Nutzt andere Commands (`enable-desktop`, `update-features-config`)
- ❌ Sollte in `homelab-manager` Feature oder separatem Core-Modul

---

## 🎯 Zusammenfassung: Was macht `system-updater`?

### ✅ **Kernfunktionen** (gehören hierher):
1. **System Config Update** - Updated NixOS Config aus Git
2. **Feature Management** - Toggle Features interaktiv
3. **Channel Update** - Updated Flake Inputs
4. **Version Checking** - Feature-Versionen prüfen & updaten
5. **Feature Migration** - Automatische Feature-Updates
6. **Config Migration** - System-Config Struktur-Migration
7. **Config Validation** - Config-Struktur validieren

### ⚠️ **Fragwürdige Funktionen**:
1. **Desktop Management** - Könnte in `desktop` Core-Modul
2. **Homelab Utilities** - Gehört definitiv NICHT hierher!

---

## 💡 Namensvorschläge

### Option 1: **`system-manager`** (empfohlen)
- ✅ Besserer Name für Multi-Purpose Modul
- ✅ Beschreibt: "Manged das System"
- ✅ Umfasst: Updates, Features, Channels, Versionen

### Option 2: **`config-manager`**
- ✅ Fokus auf Config-Management
- ❌ Aber: Macht auch mehr (Channels, Versionen)

### Option 3: **`system-updater`** (behalten)
- ✅ Klar: Updated System
- ❌ Aber: Macht mehr als nur Updates

---

## 🔧 Refactoring-Empfehlungen

### 1. **Homelab-Utils trennen** ⚠️ **HIGH PRIORITY**
- ❌ `lib/homelab-utils.nix` gehört NICHT in `system-updater`
- ✅ **Option A**: Nach `core/homelab` verschieben (wenn Core-Modul)
- ✅ **Option B**: Nach `features/homelab-manager/lib/` verschieben
- ✅ **Option C**: Eigenes `core/homelab-utils` Modul

### 2. **Desktop-Manager trennen?** (optional)
- ⚠️ Könnte in `core/desktop` Modul
- ✅ Aber: Wird auch von `system-update` verwendet
- 💡 **Empfehlung**: Bleibt hier, da eng mit System-Management verbunden

### 3. **Struktur verbessern**:
```
system-manager/ (oder system-updater/)
├── handlers/
│   ├── system-update.nix      # System Config Update
│   ├── feature-manager.nix     # Feature Toggling
│   ├── channel-manager.nix     # Flake Update
│   ├── desktop-manager.nix     # Desktop Toggle
│   ├── module-version-check.nix # Version Checking (Core + Features)
│   └── feature-migration.nix   # Feature Migration
├── scripts/
│   ├── check-versions.nix      # CLI: check-module-versions
│   └── smart-update.nix        # CLI: update-features
├── validators/
│   └── config-validator.nix    # Config Validation
└── config-migration.nix        # System Config Migration
```

---

## 📊 Funktions-Matrix

| Funktion | Command | Gehört hierher? | Alternative |
|----------|---------|-----------------|-------------|
| System Config Update | `ncc system-update` | ✅ Ja | - |
| Feature Management | `ncc feature-manager` | ✅ Ja | - |
| Channel Update | `ncc update-channels` | ✅ Ja | - |
| Desktop Toggle | `ncc desktop-manager` | ⚠️ Vielleicht | `core/desktop` |
| Version Check | `ncc check-module-versions` | ✅ Ja | Core + Features |
| Feature Update | `ncc update-features` | ✅ Ja | - |
| System Config Migration | `ncc migrate-system-config` | ✅ Ja | - |
| System Config Validation | `ncc validate-system-config` | ✅ Ja | - |
| **Homelab Minimize** | `ncc homelab-minimize` | ❌ **NEIN** | `homelab-manager` oder `core/homelab` |

---

## 🎯 Fazit

### **Was `system-updater` macht:**
1. ✅ Updated komplette NixOS Config (außer Custom)
2. ✅ Managed Features (enable/disable)
3. ✅ Updated Channels/Flake Inputs
4. ✅ Managed Module-Versionen (Core + Features, check & update)
5. ✅ Migriert System-Config & Feature-Configs
6. ✅ Validiert Config-Struktur
7. ❌ **Homelab-spezifische Utilities** (sollte raus!)

### **Empfehlung:**
1. ⚠️ **Sofort**: `homelab-utils.nix` aus `system-updater` entfernen
2. 💡 **Optional**: Umbenennen zu `system-manager` (besserer Name)
3. ✅ **Struktur**: Aktuelle Struktur ist gut (nach Template)

### **Nächste Schritte:**
1. `homelab-utils.nix` → `features/homelab-manager/lib/` oder `core/homelab/`
2. Command `ncc homelab-minimize` entsprechend verschieben
3. Optional: Umbenennen zu `system-manager`

