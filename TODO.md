[2 tools called]

**OKAY, ICH VERSTEHE!** Dein Template ist das Ziel - lass mich einen **NEUEN PLAN** erstellen, der das Template als **RICHTIG** annimmt und ALLES dahin migriert:

## 🎯 **NEUER PLAN: Migration zu Template-konformer Architektur**

Das Template definiert die **einheitliche Architektur** mit `systemConfig.core.*` und `systemConfig.features.*`. Alles andere ist falsch!

### **Template-konforme Ziel-Architektur:**

```nix
# Wie im Template definiert:
options.systemConfig = {
  core.system.audio = { ... };           # Core System
  core.management.logging = { ... };     # Core Management  
  core.infrastructure.cli-formatter = { ... }; # Core Infrastructure
  features.infrastructure.homelab = { ... };    # Features
  features.security.ssh-server = { ... };
};

# Alle Module verwenden systemConfig.* (wie Template sagt)
{ systemConfig, ... }:
let
  audioCfg = systemConfig.core.system.audio;
  homelabCfg = systemConfig.features.infrastructure.homelab;
in {
  # Implementation
}
```

---

## 📋 **Template-konforme Migrations-Phasen:**

### **Phase 1: Command-Center korrigieren (Template-konform)**
**Problem:** Verwendet falsche `core.command-center.commands` statt `systemConfig.command-center.commands`

| Datei | FALSCH | RICHTIG (nach Template) |
|-------|--------|------------------------|
| `handlers/desktop-manager.nix` | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |
| `handlers/system-update.nix` | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |
| `commands.nix` (system-manager) | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |
| `commands.nix` (logging) | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |
| `commands.nix` (checks) | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |
| `homelab/default.nix` | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |

### **Phase 2: Config-Zugriffe korrigieren (Template-konform)**
**Problem:** Module lesen von falschen Quellen statt `systemConfig.*`

| Datei | FALSCH | RICHTIG (nach Template) |
|-------|--------|------------------------|
| `module-manager/config.nix` | `config.core.management.module-manager` | `systemConfig.core.management.module-manager` |
| `checks/config.nix` | `config.management.checks` | `systemConfig.management.checks` |
| `checks/default.nix` | `config.management.checks` | `systemConfig.management.checks` |

### **Phase 3: Features korrigieren (Template-konform)**
**Problem:** Features verwenden gemischte `config.*` und `systemConfig.*` APIs

| Datei | FALSCH | RICHTIG (nach Template) |
|-------|--------|------------------------|
| `homelab/config.nix` | `config.features.infrastructure.homelab.enable` | `systemConfig.features.infrastructure.homelab.enable` |
| `homelab/default.nix` | `config.features.infrastructure.homelab` | `systemConfig.features.infrastructure.homelab` |
| `packages/default.nix` | `config.features.ai-workspace` | `systemConfig.features.ai-workspace` |
| `ssh-server/default.nix` | `config.features.security.ssh-server` | `systemConfig.features.security.ssh-server` |
| `ssh-client/default.nix` | `config.features.security.ssh-client` | `systemConfig.features.security.ssh-client` |
| `bootentry/default.nix` | `config.features.infrastructure.bootentry` | `systemConfig.features.infrastructure.bootentry` |
| `vm/default.nix` | `config.features.infrastructure.vm` | `systemConfig.features.infrastructure.vm` |
| `hackathon/default.nix` | `config.features.specialized.hackathon` | `systemConfig.features.specialized.hackathon` |
| `lock/default.nix` | `config.features.system.lock` | `systemConfig.features.system.lock` |
| `ai-workspace/default.nix` | `config.features.ai-workspace` | `systemConfig.features.ai-workspace` |

### **Phase 4: Options korrigieren (Template-konform)**
**Problem:** Options sind falsch definiert

| Datei | FALSCH | RICHTIG (nach Template) |
|-------|--------|------------------------|
| `command-center/options.nix` | `options.config.core.command-center` | `options.systemConfig.command-center` |
| `module-manager/options.nix` | `options.config.core.management.module-manager` | `options.systemConfig.core.management.module-manager` |

---

## 🚀 **SICHERE, MANUELLE AUSFÜHRUNG (Template-konform):**

**❌ KEINE sed-Befehle!** Zu gefährlich - könnten Kommentare/Strings/Teilstrings zerstören!

### **Sicherer Plan: Datei für Datei manuell korrigieren**

#### **1. Command-Center API korrigieren**
**Problem:** Module verwenden `core.command-center.commands` statt `systemConfig.command-center.commands`

| Datei | Zeile | FALSCH | RICHTIG |
|-------|-------|--------|---------|
| `handlers/desktop-manager.nix` | 93 | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |
| `handlers/system-update.nix` | ? | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |
| `system-manager/commands.nix` | 45 | `core.command-center.commands =` | `systemConfig.command-center.commands =` |
| `logging/commands.nix` | ? | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |
| `checks/commands.nix` | ? | `core.command-center.commands = [` | `systemConfig.command-center.commands = [` |
| `homelab/default.nix` | 59 | `core.command-center.commands =` | `systemConfig.command-center.commands =` |

#### **2. Feature API korrigieren**
**Problem:** Features verwenden `config.features.*` statt `systemConfig.features.*`

| Datei | Zeile | FALSCH | RICHTIG |
|-------|-------|--------|---------|
| `homelab/config.nix` | 4 | `cfg = config.features.infrastructure.homelab;` | `cfg = systemConfig.features.infrastructure.homelab;` |
| `homelab/default.nix` | 6 | `cfg = config.features.infrastructure.homelab;` | `cfg = systemConfig.features.infrastructure.homelab;` |
| `hackathon/default.nix` | 6 | `cfg = config.features.specialized.hackathon;` | `cfg = systemConfig.features.specialized.hackathon;` |
| `ai-workspace/default.nix` | 6 | `cfg = config.features.ai-workspace;` | `cfg = systemConfig.features.ai-workspace;` |
| `ssh-server/default.nix` | ? | `cfg = config.features.security.ssh-server;` | `cfg = systemConfig.features.security.ssh-server;` |
| `ssh-client/default.nix` | ? | `cfg = config.features.ssh-client-manager;` | `cfg = systemConfig.features.security.ssh-client;` |
| `bootentry/default.nix` | ? | `cfg = config.features.infrastructure.bootentry;` | `cfg = systemConfig.features.infrastructure.bootentry;` |
| `vm/default.nix` | ? | `cfg = config.features.infrastructure.vm;` | `cfg = systemConfig.features.infrastructure.vm;` |
| `lock/default.nix` | ? | `cfg = config.features.system.lock;` | `cfg = systemConfig.features.system.lock;` |

#### **3. Options korrigieren**
**Problem:** Options verwenden `options.core.*` statt `options.systemConfig.*`

| Datei | Zeile | FALSCH | RICHTIG |
|-------|-------|--------|---------|
| `module-manager/options.nix` | 6 | `options.core.management.module-manager` | `options.systemConfig.core.management.module-manager` |

#### **4. Script-API Zugriffe korrigieren**
**Problem:** Scripts verwenden `config.features.*` für Version-Zugriffe

| Datei | Zeile | FALSCH | RICHTIG |
|-------|-------|--------|---------|
| `update-features.nix` | ? | `config.features.$feature._version` | `systemConfig.features.$feature._version` |
| `check-versions.nix` | ? | `config.features.$feature._version` | `systemConfig.features.$feature._version` |

---

## ✅ **Validierung (Template-konform):**

```bash
# Build-Test
sudo nixos-rebuild build --flake /etc/nixos

# Template-Konformität prüfen
echo "=== Verbleibende falsche API-Zugriffe ==="
echo "config.core.* (sollte nur options.* sein):"
grep -r "config\.core\." nixos/ | grep -v "#\|README\|options\."
echo
echo "config.features.* (sollte leer sein):"
grep -r "config\.features\." nixos/ | grep -v "#\|README"
echo
echo "core.command-center.commands (sollte systemConfig.command-center.commands sein):"
grep -r "core\.command-center\.commands" nixos/ | grep -v "#\|README"
echo
echo "options.core.* (sollte options.systemConfig.* sein):"
grep -r "options\.core\." nixos/ | grep -v "#\|README"
echo
echo "=== Korrekte API-Zugriffe ==="
echo "systemConfig.* Zugriffe:"
grep -r "systemConfig\." nixos/ | wc -l
```

**GESAMT:** ~12 Dateien manuell korrigieren, alles zu `systemConfig.*` wie dein Template sagt!

**❌ KEINE sed-Befehle!** Zu gefährlich - würden Kommentare/Strings beschädigen!

Das ist der **SICHERE Plan** nach deinem Template! 🛡️🔧

Soll ich das jetzt manuell Datei für Datei korrigieren?