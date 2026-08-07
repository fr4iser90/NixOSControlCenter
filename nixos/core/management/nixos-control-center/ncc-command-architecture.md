# NCC Command Architecture - Design Document

> **Normative CLI rules live in [doc/CLI-SCHEMA.md](./doc/CLI-SCHEMA.md).**  
> This file is historical design notes; on naming/domains/aliases, CLI-SCHEMA wins.

## Übersicht

Dieses Dokument beschreibt die Architektur für das `ncc` Command-System in einer modularen NixOS-Konfiguration. Es adressiert:
- **3-Ebenen-Architektur:** Core-Commands (flach) vs. Feature-Module (hierarchisch)
- Modul-Registrierung mit expliziter `scope`-Trennung
- Unterstützung für verschiedene UI-Formate (fzf + Bubble Tea TUI)
- Interne vs. öffentliche Commands

---

## 1. Command-Struktur: 3-Ebenen-Architektur

### 1.1 Das Architektur-Prinzip

**Kernidee:** Nicht alles muss hierarchisch sein. Die Struktur folgt dem **mentalen Modell** des Users.

NCC soll sich wie ein **Betriebssystem-Interface** anfühlen:
- Einige starke Top-Level-Commands (wie Shell-Builtins)
- Darunter modulare Subsysteme (wie `docker`, `git`, `systemctl`)

### 1.2 Die 3 Ebenen

#### 1️⃣ Core-System-Commands (flach lassen!)

**Das sind Dinge, die sich wie Shell-Builtins anfühlen.**

```bash
ncc system build       # System bauen
ncc system update      # System aktualisieren
ncc switch             # System wechseln
ncc rollback           # System zurücksetzen
```

**Warum flach?**
- Mentales Modell: "ncc ist mein System-Frontend"
- Nicht: "ncc system-manager update" (unnötig verschachtelt)
- UX bleibt intuitiv und schnell

**Vergleich:** Wie `git commit`, nicht `git repository-manager commit`

#### 2️⃣ Feature-Module (hierarchisch)

**Das sind Dinge mit klar abgegrenztem Domänenmodell.**

```bash
ncc module-manager enable <module>    # Modul-Management
ncc homelab-manager init-swarm        # Homelab-Management
ncc backup-manager create             # Backup-Management
```

**Warum hierarchisch?**
- Logische Gruppierung verwandter Aktionen
- Skaliert für viele Subcommands
- Vermeidet Command-Namens-Kollisionen
- Klare Domänen-Trennung

#### 3️⃣ Namespaces (nur wenn nötig)

**Nur dann, wenn:**
- Ein Modul sehr groß wird
- Viele Subcommands entstehen
- Versionierung oder Isolation gewünscht

**Aber:** Ein Namespace nur aus Prinzip → macht CLI schwerer.

### 1.3 Explizite Trennung: `scope`

**Das ist der Schlüssel:** Explizite Trennung statt impliziter Hierarchie.

```nix
scope = lib.types.enum [
  "core"      # Core-System-Command (flach, kein parent erlaubt)
  "module"    # Feature-Modul (hierarchisch, parent möglich)
];
```

**Regeln:**
- `scope = "core"` → **keine** `parent` erlaubt, immer Top-Level
- `scope = "module"` → `parent` möglich für Subcommands

**Damit ist die Architektur sauber getrennt, aber UX bleibt intuitiv.**

---

## 2. Modul-Registrierung

### 2.1 Automatische Registrierung

**Pattern:** Jedes Modul registriert sich selbst über `commands.nix`

**Wichtig:** `scope` bestimmt die Struktur!

### 2.2 Core-Commands (scope = "core")

**Beispiel:** System-Update Command

```nix
# nixos/core/management/system-manager/commands.nix
(cliRegistry.registerCommandsFor "system-manager" [
  {
    name = "system-update";
    scope = "core";              # ← Core-System-Command
    type = "command";
    description = "Update NixOS configuration from repository";
    script = "${systemUpdateScript}/bin/ncc-system-update";
    category = "system";
    # parent = null;             # ← Nicht erlaubt bei scope = "core"
  }
  {
    name = "build";
    scope = "core";
    type = "command";
    description = "Build and activate NixOS configuration";
    script = "${buildScript}/bin/ncc-build";
    category = "system";
  }
])
```

**Usage:** `ncc system update`, `ncc system build` (hierarchisch, domain-basiert)

### 2.3 Feature-Module (scope = "module")

**Beispiel:** Homelab-Manager

```nix
# nixos/modules/infrastructure/homelab-manager/commands.nix
(cliRegistry.registerCommandsFor "homelab-manager" [
  {
    name = "homelab-manager";
    scope = "module";            # ← Feature-Modul
    type = "manager";
    description = "Homelab infrastructure management";
    script = "${homelabManagerScript}/bin/ncc-homelab-manager";
    category = "infrastructure";
  }
  {
    name = "status";
    scope = "module";
    parent = "homelab-manager";  # ← Subcommand erlaubt
    type = "command";
    description = "Show homelab status";
    script = "${homelabStatusScript}/bin/ncc-homelab-status";
  }
  {
    name = "init-swarm";
    scope = "module";
    parent = "homelab-manager";
    type = "command";
    description = "Initialize Docker Swarm";
    script = "${homelabInitSwarmScript}/bin/ncc-homelab-init-swarm";
    dangerous = true;
  }
])
```

**Usage:** `ncc homelab-manager status`, `ncc homelab-manager init-swarm` (hierarchisch)

### 2.4 Command-Hierarchie-Regeln

**Explizite Parent-Beziehung (Empfohlen)**
```nix
{
  name = "get-module-data";
  scope = "module";
  parent = "module-manager";  # Subcommand von module-manager
  internal = true;            # Versteckt in öffentlicher Hilfe
}
```

**Validierung:**
- `scope = "core"` → `parent` muss `null` sein
- `scope = "module"` → `parent` optional (für Subcommands)

---

## 3. UI-Format-Unterstützung

### 3.1 Dual-Format Support (Migration)

**Problem:** Einige Module nutzen fzf, andere Bubble Tea TUI

**Lösung:** Beide Formate unterstützen, Migration schrittweise

```nix
{
  name = "module-manager";
  type = "manager";
  ui = {
    format = "bubbletea";     # "bubbletea" | "fzf" | "auto"
    script = "${bubbleTeaTui}/bin/ncc-module-manager-tui";
    fallback = "${fzfScript}/bin/ncc-module-manager-fzf";  # Optional
  };
}
```

### 3.2 Auto-Detection

```nix
ui = {
  format = "auto";  # Automatisch bestes Format wählen
  # Priority: bubbletea > fzf > simple
};
```

### 3.3 Migration-Strategie

**Phase 1:** Beide Formate parallel
- Neue Module: Bubble Tea TUI
- Alte Module: fzf (mit Migration-Path)

**Phase 2:** fzf als Fallback
- Bubble Tea als Standard
- fzf nur wenn Bubble Tea nicht verfügbar

**Phase 3:** fzf entfernen (optional)
- Nur Bubble Tea TUI

---

## 4. Interne Commands

### 4.1 Internal Flag

**Aktuell:** Nicht im `types.nix` implementiert

**Erweiterung:**
```nix
{
  name = "get-module-data";
  internal = true;  # Versteckt in `ncc help`, aber ausführbar
  description = "Internal: Get module discovery data";
}
```

**Verhalten:**
- ✅ Ausführbar: `ncc module-manager get-module-data`
- ❌ Nicht in `ncc help` gelistet
- ✅ In `ncc help module-manager` (wenn parent command)

---

## 5. Command-Discovery & Help-System

### 5.1 Hierarchische Help

```bash
# Top-level Help
ncc help
# → Zeigt alle öffentlichen Commands (ohne internal)

# Command-spezifische Help
ncc help module-manager
# → Zeigt alle Subcommands (inkl. internal)
```

### 5.2 Command-Resolution

**Aktuell:** Flache Command-Liste

**Erweitert:** Hierarchische Resolution
```bash
ncc module-manager get-module-data
# 1. Finde "module-manager" (type = "manager")
# 2. Prüfe ob "get-module-data" Subcommand ist
# 3. Führe Script mit Subcommand aus
```

---

## 6. Implementierungs-Plan

### Phase 1: Types erweitern

**Datei:** `nixos/core/management/cli-registry/lib/types.nix`

```nix
{
  # ... bestehende Optionen ...
  
  # NEU: Explizite Scope-Trennung
  scope = lib.mkOption {
    type = lib.types.enum [ "core" "module" ];
    default = "module";
    description = ''
      Command scope:
      - "core": Core-System-Command (flach, kein parent erlaubt)
      - "module": Feature-Modul (hierarchisch, parent möglich)
    '';
  };
  
  parent = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Parent command name for subcommands (only allowed for scope = 'module')";
    example = "module-manager";
    # Validierung: parent nur erlaubt wenn scope = "module"
  };
  
  internal = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Hide from public help (but still executable)";
  };
  
  ui = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        format = lib.mkOption {
          type = lib.types.enum [ "bubbletea" "fzf" "auto" ];
          default = "auto";
        };
        script = lib.mkOption {
          type = lib.types.path;
        };
        fallback = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
        };
      };
    });
    default = null;
    description = "UI configuration (for manager-type commands)";
  };
}
```

**Validierung hinzufügen:**
```nix
# In types.nix oder config.nix
lib.mkIf (cmd.scope == "core" && cmd.parent != null) (
  throw "Core commands cannot have a parent: ${cmd.name}"
)
```

### Phase 2: CLI Registry API erweitern

**Datei:** `nixos/core/management/cli-registry/api.nix`

```nix
{
  # ... bestehende Funktionen ...
  
  # Get commands by parent
  getSubcommands = config: parentName:
    let
      allCommands = getRegisteredCommands config;
    in
      lib.filter (cmd: cmd.parent or null == parentName) allCommands;
  
  # Get public commands (exclude internal)
  getPublicCommands = config:
    lib.filter (cmd: !(cmd.internal or false)) (getRegisteredCommands config);
}
```

### Phase 3: Main Script erweitern

**Datei:** `nixos/core/management/cli-registry/scripts/main-script.nix`

- Hierarchische Command-Resolution
- Subcommand-Handling
- Help-System für Manager-Commands

---

## 7. Best Practices

### 7.1 Command-Naming

✅ **Gut:**
```nix
name = "module-manager";        # Klar, beschreibend
name = "homelab-manager";       # Modul-basiert
```

❌ **Schlecht:**
```nix
name = "mm";                    # Zu kurz, unklar
name = "manager";               # Zu generisch
```

### 7.2 Scope vs. Type: Wann was?

**Scope = "core":** Für System-Primitives
```nix
{
  name = "build";
  scope = "core";        # ← Core-System-Command
  type = "command";
  # Direkt ausführbar, keine Subcommands
  # parent = null (erzwungen)
}
```

**Scope = "module" + Type = "manager":** Für Feature-Module mit Subcommands
```nix
{
  name = "module-manager";
  scope = "module";       # ← Feature-Modul
  type = "manager";
  # Subcommands: enable, disable, list, status
}
```

**Scope = "module" + Type = "command":** Für einfache Modul-Commands
```nix
{
  name = "homelab-status";
  scope = "module";
  type = "command";
  parent = "homelab-manager";  # ← Optional, für Gruppierung
}
```

**Entscheidungsmatrix:**

| Use Case | scope | type | parent |
|----------|-------|------|--------|
| System-Update | `core` | `command` | ❌ nicht erlaubt |
| System-Build | `core` | `command` | ❌ nicht erlaubt |
| Modul-Management | `module` | `manager` | ❌ (Top-Level) |
| Modul-Subcommand | `module` | `command` | ✅ (z.B. "module-manager") |

### 7.3 Scope-Auswahl: Wann "core" vs. "module"?

**Fragen zur Entscheidung:**

1. **Ist es ein System-Primitive?**
   - Betrifft es das gesamte System?
   - Fühlt es sich wie ein Shell-Builtin an?
   - → `scope = "core"`

2. **Ist es Teil eines Feature-Moduls?**
   - Gehört es zu einer spezifischen Domäne?
   - Gibt es verwandte Aktionen?
   - → `scope = "module"`

**Beispiele:**

| Command | scope | Begründung |
|---------|-------|------------|
| `build` | `core` | System-Primitive, betrifft gesamtes System |
| `system-update` | `core` | System-Operation, kein Modul |
| `module-manager` | `module` | Feature-Modul mit Subcommands |
| `homelab-manager` | `module` | Domänen-spezifisch, hat Subcommands |
| `backup-manager` | `module` | Feature-Modul, nicht System-Primitive |

**Goldene Regel:**
- Wenn du dir unsicher bist → `scope = "module"`
- Nur echte System-Primitives → `scope = "core"`

### 7.4 UI-Format wählen

**Bubble Tea TUI:** Für komplexe, interaktive Interfaces
- Module-Manager
- System-Konfiguration
- Multi-Step-Workflows

**fzf:** Für einfache Auswahl-Menüs
- Einfache Listen
- Quick-Actions
- Legacy-Support

**Simple:** Für non-interactive Commands
- Status-Checks
- One-Shot-Commands
- Scripts ohne UI

---

## 8. Beispiel-Implementierung

### 8.1 Core-Commands (scope = "core")

```nix
# nixos/core/management/system-manager/commands.nix
(cliRegistry.registerCommandsFor "system-manager" [
  {
    name = "system-update";
    scope = "core";              # ← Core-System-Command
    type = "command";
    description = "Update NixOS configuration from repository";
    script = "${systemUpdateScript}/bin/ncc-system-update";
    category = "system";
    # parent = null (erzwungen bei scope = "core")
  }
  {
    name = "build";
    scope = "core";
    type = "command";
    description = "Build and activate NixOS configuration";
    script = "${buildScript}/bin/ncc-build";
    category = "system";
  }
])
```

**Usage:** `ncc system-update`, `ncc build` (flach, direkt)

### 8.2 Module-Manager (scope = "module", type = "manager")

```nix
# nixos/core/management/module-manager/commands.nix
(cliRegistry.registerCommandsFor "module-manager" [
  {
    name = "module-manager";
    scope = "module";            # ← Feature-Modul
    type = "manager";
    description = "Interactive module management TUI";
    script = "${moduleManagerTui}/bin/ncc-module-manager";
    category = "system";
    ui = {
      format = "bubbletea";
      script = "${bubbleTeaTui}/bin/ncc-module-manager-tui";
    };
  }
  {
    name = "get-module-data";
    scope = "module";
    parent = "module-manager";   # ← Subcommand erlaubt
    type = "command";
    description = "Internal: Get module discovery data";
    script = "${discoveryScript}/bin/get-module-data";
    internal = true;
  }
])
```

**Usage:** `ncc module-manager`, `ncc module-manager get-module-data`

### 8.3 Homelab-Manager (scope = "module", hierarchisch)

```nix
# nixos/modules/infrastructure/homelab-manager/commands.nix
(cliRegistry.registerCommandsFor "homelab-manager" [
  {
    name = "homelab-manager";
    scope = "module";            # ← Feature-Modul
    type = "manager";
    description = "Homelab infrastructure management";
    script = "${homelabManagerScript}/bin/ncc-homelab-manager";
    category = "infrastructure";
  }
  {
    name = "status";
    scope = "module";
    parent = "homelab-manager";  # ← Subcommand erlaubt
    type = "command";
    description = "Show homelab status";
    script = "${homelabStatusScript}/bin/ncc-homelab-status";
  }
  {
    name = "init-swarm";
    scope = "module";
    parent = "homelab-manager";
    type = "command";
    description = "Initialize Docker Swarm";
    script = "${homelabInitSwarmScript}/bin/ncc-homelab-init-swarm";
    dangerous = true;
  }
])
```

**Usage:**
```bash
ncc homelab-manager              # TUI starten
ncc homelab-manager status       # Status anzeigen
ncc homelab-manager init-swarm   # Swarm initialisieren
```

---

## 9. Migration von bestehenden Commands

### 9.1 Schritt-für-Schritt

1. **Identifiziere Manager-Commands**
   - Commands mit Subcommands → `type = "manager"`

2. **Extrahiere Subcommands**
   - Interne Scripts → separate Commands mit `parent`

3. **UI-Format migrieren**
   - fzf → Bubble Tea (optional, parallel möglich)

4. **Internal-Flag setzen**
   - Discovery-Scripts → `internal = true`

---

## 10. Zusammenfassung

### ✅ Kern-Empfehlungen

1. **3-Ebenen-Architektur:**
   - **Core-Commands** (`scope = "core"`): Flach, wie Shell-Builtins
   - **Feature-Module** (`scope = "module"`): Hierarchisch, mit Subcommands
   - **Namespaces:** Nur wenn wirklich nötig

2. **Explizite Trennung:** `scope`-Feld statt impliziter Hierarchie
   - `scope = "core"` → kein `parent` erlaubt
   - `scope = "module"` → `parent` möglich

3. **UX-First:** Nicht dogmatisch hierarchisch, sondern ergonomisch
   - `ncc system-update` ✅ (Core-Command, flach)
   - `ncc module-manager enable` ✅ (Feature-Modul, hierarchisch)

4. **Dual-Format Support:** Bubble Tea + fzf während Migration

5. **Internal-Flag:** Für Discovery/Helper-Commands

6. **Automatische Registrierung:** Über `commands.nix` pro Modul

### 🎯 Vorteile

- **Architektonisch sauber:** Explizite Trennung via `scope`
- **UX-freundlich:** Core-Commands bleiben flach und schnell
- **Skalierbar:** Neue Module fügen sich automatisch ein
- **Konsistent:** Einheitliches Pattern, aber nicht dogmatisch
- **Flexibel:** Unterstützung für verschiedene UI-Formate

### 🧠 Design-Philosophie

**Nicht:** "Alles muss hierarchisch sein"

**Sondern:** "Alles muss konsistent kategorisiert sein"

**Vergleich:** Wie `docker build`, `docker swarm init` - nicht alles gleich tief verschachtelt, aber konsistent strukturiert.

### 📋 Nächste Schritte

1. **Types erweitern** (`types.nix`): `scope`-Feld hinzufügen
2. **Validierung:** `scope = "core"` → `parent = null` erzwingen
3. **API erweitern** (`api.nix`): Helper für Core vs. Module
4. **Main Script anpassen:** Hierarchische Resolution für Module
5. **Beispiel-Module migrieren:** `system-update` → `scope = "core"`
6. **Dokumentation aktualisieren:** Best Practices für Scope-Auswahl
