# 🎯 NCC - NixOS Control Center: Architektur & Workflow

## 🏗️ NCC Aufbau: Terminal-First mit TUI-Unterstützung

### Terminal-First Ansatz
```bash
# Hauptbefehl
ncc

# Modul-Management
ncc module-manager          # TUI für Modul-Aktivierung
ncc module enable homelab   # Direkter Befehl
ncc module disable homelab  # Direkter Befehl

# System-Management
ncc system update           # System aktualisieren
ncc system check            # System prüfen
ncc system backup           # Backup erstellen

# User-Management
ncc user create username    # User erstellen
ncc user delete username    # User löschen
ncc user list               # User auflisten
```

### TUI (Text User Interface) für komplexe Aufgaben
```bash
# Für Modul-Management: fzf-TUI
ncc module-manager  # Öffnet interaktive Auswahl

# Für User-Management: Einfache Menus
ncc user-manager    # User-Management TUI
```

## ⚙️ Modul-Aktivierung: Terminal + Automatische Config-Erstellung

### 1. Modul aktivieren
```bash
ncc module enable homelab
# → Erstellt automatisch: /etc/nixos/systemConfig/modules/infrastructure/homelab/config.nix
```

### 2. Config-Template verwenden
```nix
# Automatisch erstellte config.nix
{
  enable = true;
  # Default-Werte aus module options
  dockerSwarm = {
    enable = false;
    role = "worker";
  };
}
```

### 3. User kann Config anpassen
```nix
# Nach Aktivierung editierbar
{
  enable = true;
  dockerSwarm = {
    enable = true;
    role = "manager";
  };
}
```

## 📁 Config-Struktur: Vollständige Übersicht

### Core Module Configs (immer aktiv)
```
configs/core/base/*/config.nix          # Basis-Konfiguration
configs/core/management/*/config.nix    # Management-Konfiguration
```

**Beispiel: packages/config.nix**
```nix
{
  # Legacy: Bleibt für Abwärtskompatibilität
  packageModules = ["gaming", "docker"];

  # Neu: Explizite Trennung
  systemPackages = ["qemu", "virt-manager"];
  userPackages = {
    fr4iser = ["vscode", "firefox"];
  };
}
```

### Optional Module Configs (enable-driven)
```
configs/modules/infrastructure/*/config.nix
configs/modules/security/*/config.nix
configs/modules/specialized/*/config.nix
```

**Beispiel: homelab/config.nix**
```nix
{
  enable = true;
  dockerSwarm = {
    enable = true;
    role = "manager";
    network = "10.0.0.0/24";
  };
  services = ["nginx", "postgresql"];
}
```

### User-spezifische Configs
```
configs/users/{username}/
├── packages.nix      # Home-Manager Packages
├── home.nix         # Home-Manager Konfiguration
└── ...              # User-spezifische Einstellungen
```

## 🔧 Automatische Config-Erstellung

### Config-Helper System
```nix
# In module-manager/lib/config-helpers.nix
createModuleConfig = { moduleName, defaultConfig, userConfig ? {} }:
  let
    template = builtins.readFile defaultConfig;
    merged = lib.recursiveUpdate (import template) userConfig;
  in merged;
```

### Workflow: Modul aktivieren
```bash
ncc module enable homelab
# 1. Prüft ob config existiert
# 2. Wenn nicht: Erstellt aus Template
# 3. Aktiviert Modul in systemConfig
# 4. NixOS rebuild
```

### Template-System
```nix
# modules/infrastructure/homelab/template-config.nix
{
  enable = true;
  dockerSwarm = {
    enable = false;
    role = "worker";
  };
  services = [];
}
```

## 🎛️ NCC-Befehle: Vollständige Übersicht

### Modul-Management
```bash
ncc module list                    # Alle verfügbaren Module
ncc module status                  # Status aller Module
ncc module enable <module>         # Modul aktivieren
ncc module disable <module>        # Modul deaktivieren
ncc module configure <module>      # Modul konfigurieren (editor)
ncc module-manager                 # Interaktive TUI
```

### System-Management
```bash
ncc system update                  # NixOS update
ncc system check                   # Pre-flight checks
ncc system backup                  # System backup
ncc system restore                 # System restore
ncc system doctor                  # Diagnose-Tool
```

### User-Management
```bash
ncc user list                      # Alle User
ncc user create <name>             # User erstellen
ncc user delete <name>             # User löschen
ncc user modify <name>             # User bearbeiten
ncc user-manager                   # User-Management TUI
```

### Package-Management
```bash
ncc package list                   # Installierte Packages
ncc package search <term>          # Packages suchen
ncc package install <pkg>          # Package installieren
ncc package remove <pkg>           # Package entfernen
ncc package-manager                # Package-Management TUI
```

## 🔄 Pathing & Automatisierung

### Automatische Pfad-Auflösung
```nix
# module-manager/lib/module-config.nix
getModuleConfig = moduleName: config.${getModuleApi moduleName};
getModuleMetadata = modulePath: getCurrentModuleMetadata modulePath;
```

### Config-Pfad Mapping
```nix
# Core Module
"packages" → "core.base.packages"
"system-manager" → "core.management.system-manager"

# Optional Module
"homelab" → "modules.infrastructure.homelab"
```

### Automatische Config-Erstellung
```bash
# Bei Modul-Aktivierung
ncc module enable homelab
# → Erstellt: configs/modules/infrastructure/homelab/config.nix
# → Inhalt: Default-Template aus template-config.nix
```

## 📋 Config-Inhalte: Was gehört wohin?

### systemConfig (NixOS Module)
```nix
# configs/core/base/packages/config.nix
{
  packageModules = ["gaming"];
  systemPackages = ["docker"];
  userPackages = {
    fr4iser = ["vscode"];
  };
}
```

### Home-Manager Configs
```nix
# configs/users/fr4iser/home.nix
{
  home.packages = [ ];  # Wird automatisch gefüllt
  programs = {
    vscode.enable = true;
    firefox.enable = true;
  };
}
```

### Modul-spezifische Configs
```nix
# configs/modules/infrastructure/homelab/config.nix
{
  enable = true;
  dockerSwarm = {
    enable = true;
    role = "manager";
  };
}
```

## 🚀 Implementierungsplan

### Phase 1: Basis NCC
- [ ] NCC-Hauptbefehl implementieren
- [ ] module-manager TUI erstellen
- [ ] Automatische Config-Erstellung

### Phase 2: Erweiterte Features
- [ ] User-Management Befehle
- [ ] Package-Management Integration
- [ ] Backup/Restore Funktionalität

### Phase 3: Polish
- [ ] Hilfe-System erweitern
- [ ] Error-Handling verbessern
- [ ] Performance optimieren

## 📝 NCC Naming Convention: Klare Befehlsstruktur

### Grundprinzipien
```bash
# NORMALE BEFEHLE:
ncc <domain> <action> [parameter]

# TUI-BEFEHLE (Interaktiv):
ncc <domain>-manager

# Domains: module, system, user, package, config
# Actions: list, enable, create, update, info, etc.
```

### Interaktive vs Command-Line

#### 🎮 Zwei Modi: Direkt + Interaktiv

**Direkt-Modus (Scripting/Automation):**
```bash
ncc module enable homelab     # Sofort ausführen
ncc system update            # Keine Interaktion
```

**Interaktiv-Modus (Exploration/Lernen):**
```bash
ncc                        # → Hauptmenü öffnen
ncc module-manager         # → Modul-TUI öffnen
ncc system                 # → System-Menü öffnen
```

#### 📊 NCC Hauptmenü (fzf-powered)

```bash
$ ncc
┌─ NixOS Control Center ──────────────────────────────┐
│ Choose a domain:                                    │
│                                                     │
│ ▸ Module Management     (10 active, 25 available)  │
│ ▸ System Operations    (NixOS 25.11, 294 packages) │
│ ▸ User Administration  (3 users, 2 admins)          │
│ ▸ Package Operations   (152 system, 45 user)        │
│ ▸ Configuration        (15 configs, 3 modified)     │
│ ▸ Help & Documentation                             │
│ ▸ Exit                                             │
│                                                     │
│ Use ↑↓ to navigate, Enter to select, ESC to exit   │
└─────────────────────────────────────────────────────┘
```

#### 🔍 Modul-Management TUI

```bash
$ ncc module-manager
┌─ Module Management ──────────────────────────────────┐
│ Search modules: ___________ 🔍                       │
│                                                     │
│ Infrastructure (3/8 active)                         │
│ ▸ ✅ homelab-manager     Docker Swarm, Services     │
│ ▸ ❌ bootentry-manager  Bootloader management       │
│ ▸ ❌ vm-manager         QEMU/KVM management         │
│                                                     │
│ Security (1/5 active)                               │
│ ▸ ✅ ssh-server-manager SSH server hardening        │
│ ▸ ❌ ssh-client-manager SSH client tools            │
│                                                     │
│ Specialized (0/3 active)                            │
│ ▸ ❌ ai-workspace       AI/ML development           │
│ ▸ ❌ hackathon          Development environment     │
│                                                     │
│ [Enable] [Disable] [Configure] [Info] [Back]       │
└─────────────────────────────────────────────────────┘
```

### 📋 Vollständige Domain- & Action-Übersicht

#### 1. 🎛️ Module Domain
```bash
# Direkt-Befehle
ncc module list                    # Tabellen-Liste aller Module
ncc module status                  # Status-Übersicht mit fzf
ncc module info <module>           # Detaillierte Info (Tabelle)
ncc module enable <module>         # Aktivieren + Config erstellen
ncc module disable <module>        # Deaktivieren
ncc module configure <module>      # Editor öffnen
ncc module update-all              # Alle Module aktualisieren

# Interaktiv
ncc module manager                 # Vollständige TUI
ncc module                        # Schnell-Menü (enable/disable)
```

#### 2. ⚙️ System Domain
```bash
# Direkt-Befehle
ncc system status                  # System-Status (Tabelle)
ncc system update                  # NixOS update
ncc system check                   # Pre-flight checks (Tabelle)
ncc system backup                  # Backup erstellen
ncc system restore                 # Backup wiederherstellen
ncc system doctor                  # Diagnose (interaktiv)

# Interaktiv
ncc system                        # System-Menü
```

#### 3. 👥 User Domain
```bash
# Direkt-Befehle
ncc user list                      # User-Liste (Tabelle)
ncc user create <name>             # User erstellen (interaktiv)
ncc user delete <name>             # User löschen
ncc user modify <name>             # User bearbeiten (interaktiv)
ncc user info <name>               # User-Details (Tabelle)

# Interaktiv
ncc user manager                   # Vollständige User-TUI
ncc user                          # User-Menü
```

#### 4. 📦 Package Domain
```bash
# Direkt-Befehle
ncc package list                   # Installierte Packages (Tabelle)
ncc package search <term>          # Suchen (fzf-Auswahl)
ncc package install <pkg>          # Installieren
ncc package remove <pkg>           # Entfernen
ncc package update                 # Aktualisieren
ncc package info <pkg>             # Package-Details (Tabelle)

# Interaktiv
ncc package-manager                # Package-TUI
ncc package                       # Package-Menü
```

#### 5. ⚙️ Config Domain
```bash
# Direkt-Befehle
ncc config list                    # Alle Configs
ncc config edit <path>             # Editor öffnen
ncc config validate <path>         # Syntax prüfen
ncc config backup <path>           # Backup erstellen

# Interaktiv
ncc config manager                 # Config-TUI
ncc config                        # Config-Menü
```

### 🎨 CLI Formatter Integration

#### Tabellen-Ausgabe (immer verwendet)
```bash
$ ncc module list
┌─ Available Modules ──────────────────────────────────────┐
│ Name              │ Category       │ Status │ Description │
├───────────────────┼────────────────┼────────┼─────────────┤
│ homelab-manager   │ infrastructure │ ✅     │ Docker...   │
│ ssh-server        │ security       │ ✅     │ SSH...      │
│ ai-workspace      │ specialized    │ ❌     │ AI/ML...    │
└───────────────────────────────────────────────────────────┘
```

#### Fortschrittsbalken (für langlaufende Operationen)
```bash
Building NixOS configuration...
[██████████████████████████████] 100% Complete
```

#### Farbcodierte Status-Anzeige
```bash
✅ Module homelab-manager enabled successfully
⚠️  Warning: Config file created, please review settings
❌ Error: Module 'invalid-module' not found
```

### 🚀 Quick Actions & Shortcuts

#### Hauptmenü Shortcuts
```bash
ncc 1    # → Module Management
ncc 2    # → System Operations
ncc 3    # → User Administration
ncc 4    # → Package Operations
ncc 5    # → Configuration
```

#### Kontext-Sensitive Shortcuts
```bash
# Im Modul-Menü
e <module>    # Enable
d <module>    # Disable
c <module>    # Configure
i <module>    # Info
```

### 📱 Responsive Design

#### Terminal-Größe berücksichtigen
- **Breit (>120 chars):** Volle Tabellen
- **Mittel (80-120 chars):** Kompakte Tabellen
- **Schmal (<80 chars):** Listen-Format

#### Fzf-Integration überall
- **Suche:** In allen Listen
- **Mehrfachauswahl:** Für Batch-Operationen
- **Preview:** Details beim Navigieren

### 🎯 Entscheidungen

#### Interaktivität
**Entscheidung:** Hybrid-Ansatz
- ✅ Direkt-Befehle für Scripting
- ✅ Interaktive TUIs für Exploration
- ✅ Automatische Fallbacks (CLI → TUI wenn Parameter fehlen)

**Domain:** Funktionsbereich (module, system, user, package)
**Action:** Aktion (list, enable, create, update, etc.)
**Parameter:** Optionale Parameter

### Vollständige Befehlsstruktur

#### 1. Modul-Management
```bash
ncc module list                    # Alle Module auflisten
ncc module status                  # Status aller Module
ncc module info <module>           # Details zu einem Modul
ncc module enable <module>         # Modul aktivieren
ncc module disable <module>        # Modul deaktivieren
ncc module configure <module>      # Modul konfigurieren
ncc module-manager                 # Interaktive TUI (fzf)
```

#### 2. System-Management
```bash
ncc system update                  # System aktualisieren
ncc system check                   # Pre-flight Checks
ncc system backup                  # System-Backup erstellen
ncc system restore                 # System wiederherstellen
ncc system doctor                  # Diagnose-Tool
ncc system status                  # System-Status anzeigen
```

#### 3. User-Management
```bash
ncc user list                      # Alle User auflisten
ncc user create <username>         # Neuen User erstellen
ncc user delete <username>         # User löschen
ncc user modify <username>         # User bearbeiten
ncc user info <username>           # User-Details anzeigen
ncc user manager                   # Interaktive User-Verwaltung
```

#### 4. Package-Management
```bash
ncc package list                   # Installierte Packages
ncc package search <term>          # Packages suchen
ncc package install <package>      # Package installieren
ncc package remove <package>       # Package entfernen
ncc package update                 # Packages aktualisieren
ncc package info <package>         # Package-Details
```

#### 5. Sonstige Befehle
```bash
ncc help                           # Hilfe anzeigen
ncc help <command>                 # Spezifische Hilfe
ncc version                        # Version anzeigen
ncc doctor                         # System-Diagnose
```

### Konsistenz-Regeln

#### ✅ RICHTIG:
```bash
ncc module enable homelab     # domain + action + parameter
ncc system update            # domain + action
ncc user create john         # domain + action + parameter
ncc package install firefox   # domain + action + parameter
```

#### ❌ FALSCH:
```bash
ncc enable-module homelab     # Falsche Reihenfolge
ncc systemupdate             # Kein Trenner
ncc create-user john         # Falsche Reihenfolge
ncc install firefox          # Fehlende Domain
```

### TUI vs Direkt-Befehle

#### Direkt-Befehle für:
- Häufige Operationen
- Scripting/Automation
- CI/CD Pipelines

#### TUI für:
- Komplexe Auswahl (viele Optionen)
- Erkundung verfügbarer Module
- Anfänger-freundlich

### Auto-Completion & Hilfe

#### Tab-Completion:
```bash
ncc module <TAB>     # → list, status, info, enable, disable, configure
ncc system <TAB>     # → update, check, backup, restore, doctor, status
ncc user <TAB>       # → list, create, delete, modify, info, manager
```

#### Hilfe-System:
```bash
ncc help             # Alle Befehle
ncc help module      # Modul-Befehle
ncc module --help    # Gleiche wie ncc help module
```

### Migration von alten Befehlen

#### Alte Befehle (deprecated):
```bash
ncc system-update     # → ncc system update
ncc update-modules    # → ncc module update-all
ncc check-users       # → ncc user check
```

#### Abwärtskompatibilität:
- Alte Befehle zeigen Deprecation-Warning
- Leiten zu neuen Befehlen um
- Werden in zukünftiger Version entfernt

## 🎯 Entscheidungen

### Terminal vs GUI
**Entscheidung:** Terminal-First mit TUI-Unterstützung
- ✅ Einfach zu automatisieren (Scripts)
- ✅ SSH-freundlich
- ✅ Ressourcen-schonend

### Config-Erstellung
**Entscheidung:** Automatisch bei Modul-Aktivierung
- ✅ User muss nicht manuell Dateien erstellen
- ✅ Konsistente Struktur
- ✅ Default-Werte werden gesetzt

### Home-Manager Integration
**Entscheidung:** Automatisch über packages-Modul
- ✅ Nahtlose Integration
- ✅ User-spezifische Packages
- ✅ Home-Manager wird automatisch konfiguriert

### Naming Convention
**Entscheidung:** `ncc <domain> <action> [parameter]`
- ✅ Konsistent und intuitiv
- ✅ Erweiterbar
- ✅ Auto-completion freundlich
- ✅ Script-freundlich

## 🧠 Brainstorming: Was fehlt noch?

### Error Handling & Resilience
```bash
# Robuste Fehlerbehandlung
ncc module enable invalid-module
# ❌ Error: Module 'invalid-module' not found
# 💡 Did you mean: 'homelab-manager'?

# Recovery-Mechanismen
ncc system rollback              # Letzte Änderung rückgängig machen
ncc config backup auto           # Automatische Backups vor Änderungen
```

### Logging & Debugging
```bash
# Verschiedene Log-Level
ncc --verbose module enable homelab  # Detaillierte Ausgabe
ncc --quiet system update           # Minimale Ausgabe
ncc log show                        # NCC-Aktivitätslog
ncc log tail                        # Live-Logging
```

### Security & Permissions

#### 🔐 Permission-System (KEIN sudo für alles!)
```bash
# Rollen-basierte Permissions (nicht sudo)
ncc system update                 # Nur admin/restricted-admin
ncc user create john              # Nur admin
ncc user modify $USER             # Eigener User (alle Rollen)
ncc package install firefox       # virtualization + admin
```

#### 👥 Rollen-Hierarchie & Capabilities
```nix
# Rollen-Definitionen in user-Modul
roles = {
  admin = {
    capabilities = [
      "system.*"          # Alle System-Befehle
      "user.*"            # Alle User-Befehle
      "package.*"         # Alle Package-Befehle
      "module.*"          # Alle Modul-Befehle
    ];
    sudoRules = [ "ALL" ];  # Volles sudo
  };

  restricted-admin = {
    capabilities = [
      "system.update"     # Nur Updates
      "system.check"      # Checks erlaubt
      "user.read"         # User-Info lesen
      "package.read"      # Package-Info lesen
    ];
    sudoRules = [ "ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild" ];
  };

  virtualization = {
    capabilities = [
      "package.docker.*"  # Nur Docker-Packages
      "system.docker.*"   # Docker-System-Befehle
    ];
    sudoRules = [
      "docker swarm *"    # Docker Swarm Befehle
      "docker node *"     # Docker Node Befehle
    ];
  };

  guest = {
    capabilities = [
      "user.read.self"    # Nur eigene User-Info
      "system.status"     # System-Status lesen
    ];
    sudoRules = [];       # Kein sudo
  };
};
```

#### 🛡️ Capability-Checking in NCC

**Wie funktioniert das genau?**

```bash
# JEDER NCC-Befehl hat definierte Permissions
ncc system update
# 1. NCC schaut: Welche Capability braucht "system update"?
#    → Definition: requires = "system.update"
# 2. NCC prüft: Hat aktueller User diese Capability?
#    → getUserCapabilities() → ["system.update", "system.check", ...]
# 3. Wenn ja: Ausführen mit sudo-Regeln der Rolle
# 4. Wenn nein: Permission denied + Vorschläge

ncc user create newuser
# → requires = "user.create"
# → Nur admin Rolle hat das
# → restricted-admin bekommt "Permission denied"

ncc user modify $USER
# → requires = "user.modify.self"
# → Alle Rollen haben das (auch guest)
```

#### 📋 Permission-Definition pro Befehl

**Wie definieren wir, welche Permissions ein Befehl braucht?**

```bash
# In NCC-Code: Jeder Befehl definiert seine Requirements
const commands = {
  'system.update': {
    requires: 'system.update',
    sudo: true,  // Braucht sudo
    description: 'Update NixOS system'
  },

  'user.create': {
    requires: 'user.create',
    sudo: false,  // User-Management läuft als root
    description: 'Create new user'
  },

  'user.modify.self': {
    requires: 'user.modify.self',
    sudo: false,
    allowSelf: true,  // Erlaubt für eigenen User
    description: 'Modify own user'
  }
};
```

#### 🔍 Wie NCC Permissions prüft

**Implementierung in NCC:**

```javascript
// Pseudocode für NCC Permission-System
function checkPermission(user, command) {
  const userCaps = getUserCapabilities(user);
  const cmdReq = commands[command].requires;

  // Prüfe Capability
  if (!userCaps.includes(cmdReq)) {
    throw new PermissionError(
      `Permission denied: Need capability '${cmdReq}'`,
      { requiredRole: getRolesWithCapability(cmdReq) }
    );
  }

  // Prüfe Self-Modification
  if (commands[command].allowSelf && isSelfModification(user, command)) {
    return true; // Immer erlaubt für eigenen User
  }

  return true;
}

// Vor jeder Befehlsausführung
function executeCommand(user, command, args) {
  checkPermission(user, command);

  // Wenn sudo nötig: Verwende Rollen-sudoRules
  if (commands[command].sudo) {
    return runWithSudo(command, args, getUserSudoRules(user));
  }

  return runCommand(command, args);
}
```

#### 👥 Wie bekommen wir User Capabilities?

**Aus dem user-Modul:**

```bash
# NCC fragt user-Modul nach Capabilities
ncc --get-capabilities fr4iser
# → user-Modul schaut in users.users.fr4iser.role
# → Gibt capabilities der Rolle zurück
# → ["system.update", "system.check", "user.modify.self"]

# Oder als API:
ncc api user-capabilities fr4iser
# → JSON: {"capabilities": ["system.*", "user.read"], "role": "restricted-admin"}
```

#### 🚫 Role-Escaping Prevention
```bash
# Wie verhindern wir Role-Escaping?

# 1. NCC läuft als normaler User (nicht root)
ncc system update
# → NCC prüft Permissions
# → Wenn erlaubt: NCC ruft sudo nixos-rebuild auf
# → sudo fragt nach Password (restricted-admin) oder nicht (admin)

# 2. Capability-System verhindert Escalation
# → User kann nicht einfach "sudo ncc system update" machen
# → NCC prüft immer die tatsächliche User-Rolle
# → Selbst wenn User sudo hat, gilt das Capability-System

# 3. Audit-Logging
ncc audit log
# → Zeigt wer was wann gemacht hat
# → Unbefugte Versuche werden geloggt
```

#### 🔒 Secure Execution Model
```bash
# NCC läuft als User-Prozess, escalated nur bei Bedarf
$ whoami
fr4iser

$ ncc system update
# 1. NCC prüft: Hat fr4iser 'system.update' Capability?
# 2. Wenn ja: NCC führt 'sudo nixos-rebuild' aus
# 3. sudo verwendet die sudo-Regeln der Rolle

# User kann nicht "escapen":
$ sudo ncc system update  # ← Verboten!
# → NCC erkennt sudo und prüft trotzdem User-Rolle
# → Capability-System gilt immer

# Korrekte Escalation:
$ ncc system update       # ← Erlaubt für admin/restricted-admin
# → NCC ruft sudo auf Basis der Rollen-sudoRules auf
```

#### 📊 Permission-Matrix
| Befehl | admin | restricted-admin | virtualization | guest |
|--------|-------|------------------|----------------|-------|
| `system update` | ✅ | ✅ | ❌ | ❌ |
| `system check` | ✅ | ✅ | ✅ | ✅ |
| `user create` | ✅ | ❌ | ❌ | ❌ |
| `user modify $USER` | ✅ | ✅ | ✅ | ✅ |
| `package install` | ✅ | ❌ | ⚠️ (nur docker) | ❌ |
| `module enable` | ✅ | ❌ | ❌ | ❌ |

**Legende:**
- ✅ Erlaubt
- ❌ Verboten
- ⚠️ Teilweise (rollen-spezifisch)

#### 💼 Wie machen das PROFESSIONELLE Systeme?

**Beispiele aus der Praxis:**

```bash
# 1. Kubernetes RBAC (Role-Based Access Control)
kubectl get pods  # → Prüft RBAC Permissions
# Error: Forbidden: User lacks permission "get" on resource "pods"

# 2. AWS IAM Policies
aws s3 ls         # → Prüft IAM Policy
# Error: AccessDenied: User: arn:aws:iam::123456789012:user/Bob
#        is not authorized to perform: s3:ListBucket

# 3. Linux sudo mit Commands
sudo systemctl restart nginx  # → sudo-Regeln prüfen
# Nur bestimmte Commands erlaubt

# 4. GitLab CI/CD Permissions
deploy to production  # → Prüft Projekt-Rollen
# Nur Maintainers dürfen deployen
```

**Professionelle Patterns:**
- ✅ **Capability-Based Security** (nicht nur Rollen)
- ✅ **Least Privilege** (nur nötige Permissions)
- ✅ **Audit Logging** (wer hat was wann gemacht)
- ✅ **Fail-Safe Defaults** (bei Unsicherheit → blocken)
- ✅ **Separation of Concerns** (Permissions ≠ Implementation)

#### 🛠️ Wie würden WIR das implementieren?

**Phase 1: Basis-Permission-System**
```bash
# 1. Capability-Definition pro Befehl
# In NCC: command-definitions.json oder in Code
{
  "system.update": {
    "requires": "system.update",
    "sudo": true,
    "dangerous": true  // Zusätzliche Warnung
  }
}

# ⚠️ Dangerous-Ignore Flag (für Automation)
# Gehört zu: nixos-control-center (NCC-Hauptmodul)
# In config.nix:
{
  core.management.nixos-control-center = {
    dangerousIgnore = true;  // Überspringt alle dangerous Warnungen
  };
}

# Beispiel für Automation/Scripting:
# ncc system update     # Keine "Sind Sie sicher?" Frage
# ncc module disable X  # Keine Bestätigung erforderlich

# ⚠️ WARNUNG: Nur für vertrauenswürdige Automation verwenden!
# Normale User sollten dangerousIgnore = false lassen

# 2. User-Capability-API
# NCC fragt user-Modul: "Was darf User X?"
# user-Modul antwortet mit Capability-Liste

# 3. Pre-Execution Check
# Vor jedem Befehl: checkPermission(user, command)
```

**Phase 2: Advanced Features**
```bash
# 1. Context-Aware Permissions
ncc user modify alice  # Anderer User → braucht "user.modify"
ncc user modify $USER  # Eigener User → braucht "user.modify.self"

# 2. Time-Based Permissions
# Z.B. restricted-admin darf nur Mo-Fr 9-17 system updates machen

# 3. Approval-Workflow
ncc system update --request-approval
# → Schickt Approval-Request an admin
# → Admin kann approve/deny
```

**Phase 3: Enterprise Features**
```bash
# 1. Multi-Factor Authentication für kritische Befehle
ncc system update  # → MFA erforderlich

# 2. Session-Management
ncc session start admin  # Temporäre admin-Rechte
ncc session status       # Zeigt aktive Sessions
ncc session end          # Beendet temporäre Rechte

# 3. Compliance & Audit
ncc compliance report    # SOX/HIPAA Compliance Report
ncc audit search --user alice --action "system.update"
```

#### 🎯 UNSERE Implementierung (pragmatisch)

**Start einfach, erweitere später:**

```bash
# Version 1.0: Basis-System
- Capability-Definition pro Befehl
- Rollen-basierte Permissions
- Sudo-Regeln aus user-Modul
- Audit-Logging

# Version 1.1: Advanced
- Context-Aware Permissions (self vs others)
- Approval-Workflow für kritische Befehle

# Version 2.0: Enterprise
- MFA für kritische Operationen
- Session-Management
- Compliance-Reports
```

**Das gibt uns ein solides, erweiterbares Security-System!** 🛡️

**Professionell UND pragmatisch!** ✅

#### 🛡️ Security-Prinzipien
1. **Defense in Depth**: Capability-System + sudo-Regeln + Audit
2. **Least Privilege**: Nur nötige Permissions pro Rolle
3. **No Root NCC**: NCC läuft nie als root
4. **Audit Everything**: Jeder Befehl wird geloggt
5. **Fail-Safe**: Bei Unsicherheit → Blocken

**Entscheidung:** Capability-System verhindert Role-Escaping vollständig! 🛡️

### Performance & Optimization
```bash
# Caching für schnellere Operationen
ncc module list --cache            # Cache verwenden
ncc cache clear                    # Cache leeren
ncc cache status                   # Cache-Status

# Parallele Operationen
ncc module update-all --parallel   # Parallel aktualisieren
ncc system check --fast            # Schnelle Checks
```

### Module-System = Plugin-System ✅

**Module SIND das Plugin-System!**
- ✅ Module können aktiviert/deaktiviert werden (`ncc module enable/disable`)
- ✅ Module erweitern NCC um neue Funktionalität
- ✅ Kein separates Plugin-System nötig

**Module als Plugins:**
```bash
# Infrastructure-Module (wie Plugins)
ncc module enable homelab-manager     # Homelab-Plugin aktivieren
ncc module enable ssh-server-manager  # SSH-Plugin aktivieren

# Security-Module (wie Plugins)
ncc module enable ssh-client-manager  # SSH-Client Plugin

# Specialized-Module (wie Plugins)
ncc module enable ai-workspace        # AI/ML Plugin
ncc module enable hackathon           # Development Plugin
```

**KEIN separates Plugin-System nötig - Module sind die Plugins!** 🎯

### Testing & Validation
```bash
# Dry-Run Modus
ncc --dry-run module enable homelab    # Simulation
ncc --dry-run system update           # Test ohne Ausführung

# Validation
ncc validate config                  # Config-Validierung
ncc validate system                  # System-Integritätsprüfung
ncc test all                         # Vollständige Testsuite
```

### Deployment & Updates
```bash
# NCC selbst aktualisieren
ncc self update                     # NCC auf neueste Version
ncc self check                      # NCC-Integritätsprüfung
ncc self backup                     # NCC-Konfiguration sichern

# Multi-Environment
ncc env list                        # Verfügbare Environments
ncc env switch production           # Environment wechseln
```

### Monitoring & Health-Checks
```bash
# System-Monitoring
ncc monitor start                   # Monitoring starten
ncc monitor status                  # Monitoring-Status
ncc monitor alerts                  # Aktive Alerts

# Health-Checks
ncc health system                   # System-Gesundheit
ncc health modules                  # Modul-Gesundheit
ncc health full                     # Vollständige Diagnose
```

### Internationalisierung & Themes
```bash
# Sprache/Themes
ncc config language de              # Deutsche Sprache
ncc config theme dark               # Dunkles Theme
ncc config theme minimal            # Minimalistisches Theme

# Lokalisierung
ncc locale set de_DE                # Deutsch (Deutschland)
ncc locale list                     # Verfügbare Sprachen
```

### Backup & Recovery
```bash
# Umfassende Backup-Strategien
ncc backup create full              # Voll-Backup
ncc backup create config            # Nur Konfiguration
ncc backup create selective         # Auswahl-Backup

ncc backup list                     # Backup-Liste
ncc backup restore <id>             # Backup wiederherstellen
ncc backup verify <id>              # Backup-Integrität prüfen
```

### Integration & APIs
```bash
# API für Scripting
ncc api modules                     # JSON-API für Module
ncc api system                      # JSON-API für System-Status

# Web-Interface (optional)
ncc web start                       # Web-UI starten
ncc web status                      # Web-UI Status
```

### Advanced Features
```bash
# Batch-Operations
ncc batch run script.ncc            # NCC-Script ausführen
ncc batch create                    # Batch-Script erstellen

# Remote-Management
ncc remote connect server           # Remote-Server verbinden
ncc remote execute "module enable homelab"  # Remote-Befehl

# Scheduling
ncc schedule add "daily" "system update"    # Geplante Aufgaben
ncc schedule list                           # Geplante Aufgaben
ncc schedule remove <id>                    # Aufgabe entfernen
```

## 🔍 Priorisierung: Was zuerst implementieren?

### Phase 1: Core NCC (bereits definiert)
- ✅ Basis-Befehle
- ✅ Modul-Management TUI
- ✅ Config-Automatisierung

### Phase 2: Essential Features (hoch priorisiert)
- 🔄 **Error Handling** (robuste Fehlerbehandlung)
- 🔄 **Logging** (Audit-Trail, Debugging)
- 🔄 **Validation** (Dry-Run, Config-Checks)
- 🔄 **Backup/Restore** (Recovery-Mechanismen)

### Phase 3: Advanced Features (mittel priorisiert)
- 🔄 **Plugin-System** (Erweiterbarkeit)
- 🔄 **Performance** (Caching, Parallelisierung)
- 🔄 **Security** (Audit, Permissions)
- 🔄 **Monitoring** (Health-Checks)

### Phase 4: Nice-to-Have (niedrig priorisiert)
- 🔄 **Internationalisierung** (i18n)
- 🔄 **Web-Interface** (GUI-Alternative)
- 🔄 **Remote-Management** (Multi-Server)
- 🔄 **Scheduling** (Cron-Integration)

## 🎯 Was fehlt noch in der Planung?

**Offene Fragen:**
- Wie genau soll das Plugin-System funktionieren?
- Welche Security-Mechanismen brauchen wir?
- Wie integrieren wir mit existierenden Tools (systemd, cron, etc.)?
- Performance-Ziele definieren?
- Testing-Strategie (Unit-Tests, Integration-Tests)?

**Was möchtest du als nächstes brainstormen?** 🤔
