# Migration Fixes: cli-formatter, command-center, desktop → core

## 📋 Übersicht

Nach der Migration von:
- `terminal-ui` → `cli-formatter` (nach `core/`)
- `command-center` → `core/`
- `desktop/` → `core/`

Müssen folgende Dateien angepasst werden:

---

## 🔧 1. Core Module anpassen

### 1.1 `core/cli-formatter/default.nix`

**Änderungen:**
- `config.features.terminal-ui` → `config.core.cli-formatter`
- `options.features.terminal-ui` → `options.core.cli-formatter`

**Datei:** `nixos/core/cli-formatter/default.nix`

```nix
# ALT:
let
  cfg = config.features.terminal-ui;
  ...
in {
  options.features.terminal-ui = { ... };
  config = {
    features.terminal-ui.api = apiValue;
  };
}

# NEU:
let
  cfg = config.core.cli-formatter;
  ...
in {
  options.core.cli-formatter = { ... };
  config = {
    core.cli-formatter.api = apiValue;
  };
}
```

---

### 1.2 `core/command-center/registry/default.nix`

**Änderungen:**
- `config.features.command-center` → `config.core.command-center`
- `options.features.command-center` → `options.core.command-center`

**Datei:** `nixos/core/command-center/registry/default.nix`

```nix
# ALT:
let
  cfg = config.features.command-center;
in {
  options.features.command-center = { ... };
}

# NEU:
let
  cfg = config.core.command-center;
in {
  options.core.command-center = { ... };
}
```

---

### 1.3 `core/command-center/cli/default.nix`

**Änderungen:**
- `config.features.command-center` → `config.core.command-center`
- `config.features.terminal-ui` → `config.core.cli-formatter`

**Datei:** `nixos/core/command-center/cli/default.nix`

```nix
# ALT:
let
  cfg = config.features.command-center;
  ui = config.features.terminal-ui.api;
  ...
  features.terminal-ui.enable = true;

# NEU:
let
  cfg = config.core.command-center;
  fmt = config.core.cli-formatter.api;
  ...
  # Kein enable nötig (Core-Modul)
```

---

## 🔧 2. Features System anpassen

### 2.1 `features/default.nix`

**Änderungen:**
- `"terminal-ui"` und `"command-center"` aus `featureModuleMap` entfernen
- `terminalUIFirst` Logik entfernen
- `features.terminal-ui.enable` entfernen

**Datei:** `nixos/features/default.nix`

```nix
# ALT:
featureModuleMap = {
  "terminal-ui" = ./terminal-ui;
  "command-center" = ./command-center;
  ...
};

terminalUIFirst = if hasAnyFeature && lib.elem "terminal-ui" allFeatures then [ ./terminal-ui ] else [];
otherModules = lib.filter (m: toString m != toString ./terminal-ui) featureModules;

config = {
  features.terminal-ui.enable = lib.mkIf (lib.elem "terminal-ui" allFeatures) true;
};

# NEU:
featureModuleMap = {
  # "terminal-ui" entfernt (ist jetzt core/cli-formatter)
  # "command-center" entfernt (ist jetzt core/command-center)
  "system-checks" = ./system-checks;
  ...
};

# terminalUIFirst entfernt (nicht mehr nötig)
# otherModules entfernt (nicht mehr nötig)

config = {
  # features.terminal-ui.enable entfernt (nicht mehr nötig)
};
```

**Vollständige Änderungen:**
- Zeile 9: `"terminal-ui" = ./terminal-ui;` → **ENTFERNEN**
- Zeile 10: `"command-center" = ./command-center;` → **ENTFERNEN**
- Zeile 123-127: `terminalUIFirst` und `otherModules` → **ENTFERNEN**
- Zeile 130: `imports = terminalUIFirst ++ otherModules;` → `imports = featureModules;`
- Zeile 134: `features.terminal-ui.enable = ...` → **ENTFERNEN**

---

### 2.2 `features/metadata.nix`

**Änderungen:**
- Alle `"terminal-ui"` → `"cli-formatter"` (aber eigentlich sollte cli-formatter nicht mehr in metadata sein, da es Core ist)
- `"command-center"` Eintrag entfernen (ist jetzt Core)
- Alle Dependencies anpassen: `"terminal-ui"` → entfernen (ist Core, keine Dependency mehr)

**Datei:** `nixos/features/metadata.nix`

```nix
# ALT:
{
  features = {
    "system-updater" = {
      dependencies = [ "terminal-ui" "command-center" ];
    };
    "command-center" = {
      dependencies = [ "terminal-ui" ];
    };
    "terminal-ui" = {
      dependencies = [];
    };
  };
}

# NEU:
{
  features = {
    "system-updater" = {
      dependencies = [];  # cli-formatter und command-center sind Core, keine Dependencies mehr
    };
    # "command-center" entfernt (ist jetzt Core)
    # "terminal-ui" entfernt (ist jetzt core/cli-formatter)
  };
}
```

**Vollständige Änderungen:**
- Zeile 7: `dependencies = [ "terminal-ui" "command-center" ];` → `dependencies = [];`
- Zeile 11: `dependencies = [ "terminal-ui" ];` → `dependencies = [];`
- Zeile 15: `dependencies = [ "terminal-ui" ];` → `dependencies = [];`
- Zeile 19: `dependencies = [ "terminal-ui" ];` → `dependencies = [];`
- Zeile 23: `dependencies = [ "terminal-ui" "command-center" ];` → `dependencies = [];`
- Zeile 26-29: `"command-center"` Eintrag → **ENTFERNEN**
- Zeile 35: `dependencies = [ "terminal-ui" "command-center" ];` → `dependencies = [];`
- Zeile 54-57: `"terminal-ui"` Eintrag → **ENTFERNEN**

---

## 🔧 3. Alle Features anpassen (terminal-ui → cli-formatter)

### 3.1 Alle `config.features.terminal-ui` → `config.core.cli-formatter`

**Betroffene Dateien:**
- `features/system-discovery/default.nix`
- `features/system-updater/update.nix`
- `features/system-updater/feature-manager.nix`
- `features/system-updater/homelab-utils.nix`
- `features/system-updater/desktop-manager.nix`
- `features/system-updater/channel-manager.nix`
- `features/system-checks/prebuild/default.nix`
- `features/system-checks/prebuild/checks/hardware/memory.nix`
- `features/system-checks/prebuild/checks/hardware/cpu.nix`
- `features/system-checks/prebuild/checks/hardware/gpu.nix`
- `features/system-checks/prebuild/checks/system/users.nix`
- `features/system-logger/default.nix`
- `features/ssh-client-manager/main.nix`
- `features/ssh-client-manager/ssh-server-utils.nix`
- `features/ssh-client-manager/connection-handler.nix`
- `features/ssh-client-manager/ssh-key-utils.nix`
- `features/ssh-client-manager/init.nix`
- `features/ssh-server-manager/default.nix`
- `features/ssh-server-manager/auth.nix`
- `features/ssh-server-manager/scripts/grant-access.nix`
- `features/ssh-server-manager/scripts/list-requests.nix`
- `features/ssh-server-manager/scripts/approve-request.nix`
- `features/ssh-server-manager/scripts/request-access.nix`
- `features/ssh-server-manager/scripts/monitor.nix`
- `features/ssh-server-manager/notifications.nix`

**Muster:**
```nix
# ALT:
let
  ui = config.features.terminal-ui.api;
  ...
  features.terminal-ui.enable = true;

# NEU:
let
  ui = config.core.cli-formatter.api;  # oder: fmt = config.core.cli-formatter.api;
  ...
  # features.terminal-ui.enable entfernt (nicht mehr nötig)
```

---

### 3.2 Alle `config.features.command-center` → `config.core.command-center`

**Betroffene Dateien:**
- `features/system-discovery/default.nix`
- `features/system-updater/update.nix`
- `features/system-updater/feature-manager.nix`
- `features/system-updater/homelab-utils.nix`
- `features/system-updater/desktop-manager.nix`
- `features/system-updater/channel-manager.nix`
- `features/ssh-server-manager/default.nix`
- `features/ssh-client-manager/main.nix`
- `features/system-checks/prebuild/default.nix`
- `features/system-checks/prebuild/checks/hardware/memory.nix`
- `features/system-checks/prebuild/checks/hardware/gpu.nix`
- `features/system-checks/prebuild/checks/system/users.nix`
- `features/ssh-server-manager/auth.nix`
- `features/ssh-server-manager/scripts/grant-access.nix`
- `features/ssh-server-manager/scripts/list-requests.nix`
- `features/ssh-server-manager/scripts/approve-request.nix`
- `features/ssh-server-manager/scripts/request-access.nix`
- `features/ssh-server-manager/scripts/monitor.nix`
- `features/ssh-server-manager/notifications.nix`

**Muster:**
```nix
# ALT:
let
  commandCenter = config.features.command-center;
  ...
  features.command-center.commands = [ ... ];

# NEU:
let
  commandCenter = config.core.command-center;
  ...
  core.command-center.commands = [ ... ];
```

---

## 📝 Zusammenfassung der Änderungen

### Core Module:
1. ✅ `core/cli-formatter/default.nix` - Options/Config-Pfade ändern
2. ✅ `core/command-center/registry/default.nix` - Options/Config-Pfade ändern
3. ✅ `core/command-center/cli/default.nix` - Options/Config-Pfade ändern

### Features System:
4. ✅ `features/default.nix` - terminal-ui/command-center entfernen, terminalUIFirst entfernen
5. ✅ `features/metadata.nix` - Dependencies anpassen, terminal-ui/command-center entfernen

### Alle Features:
6. ✅ Alle `config.features.terminal-ui` → `config.core.cli-formatter` (ca. 25 Dateien)
7. ✅ Alle `config.features.command-center` → `config.core.command-center` (ca. 20 Dateien)
8. ✅ Alle `features.terminal-ui.enable = true;` → **ENTFERNEN**
9. ✅ Alle `features.command-center.commands` → `core.command-center.commands`

---

## 🎯 Reihenfolge der Änderungen

1. **Zuerst Core Module anpassen** (damit Options definiert sind)
2. **Dann Features System anpassen** (damit Dependencies korrekt sind)
3. **Dann alle Features anpassen** (damit sie auf Core zugreifen)

---

## ⚠️ Wichtige Hinweise

1. **cli-formatter ist jetzt Core**: Keine Dependency mehr in `metadata.nix`, API ist immer verfügbar
2. **command-center ist jetzt Core**: Keine Dependency mehr in `metadata.nix`, API ist immer verfügbar
3. **desktop ist jetzt Core**: Wird über `systemConfig.desktop.enable` gesteuert, nicht über `features.desktop`
4. **Kein `enable` mehr nötig**: Core-Module haben kein `enable` (außer desktop, das über `systemConfig.desktop.enable` gesteuert wird)

---

## 🔍 Prüfung nach Migration

Nach allen Änderungen prüfen:
- ✅ `nix flake check` läuft durch
- ✅ `nixos-rebuild switch` funktioniert
- ✅ Alle Commands funktionieren (`ncc help`, etc.)
- ✅ Keine `terminal-ui` oder `command-center` Referenzen mehr in Features

