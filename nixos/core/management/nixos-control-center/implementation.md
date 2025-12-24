# NixOS Control Center - KORREKTE Implementation (GENAU WIE SYSTEM-MANAGER!)

## Executive Summary

**NCC = SYSTEM-MANAGER für CLI-Management!**
- Genauso wie system-manager: Core-Modul MIT generischen Submodules
- NCC wird zu core/default.nix hinzugefügt → bekommt `getCurrentModuleMetadata` automatisch von flake.nix
- NCC Submodules bekommen `getCurrentModuleMetadata` automatisch weitergegeben!
- NCC Submodules machen `moduleName = baseNameOf ./.` selbst (wie system-manager Submodules)
- NCC Submodules setzen `_module.args.moduleName` selbst (wie system-manager Submodules)
- cli-formatter & cli-registry einfach aus system-manager verschieben
- KEINE hardcoded Pfade - alles generisch!

## KORREKTE Struktur (GENAU WIE SYSTEM-MANAGER!)

```bash
core/management/nixos-control-center/
├── default.nix                    # NCC ist Core-Modul: bekommt getCurrentModuleMetadata automatisch
├── options.nix                    # NCC: getCurrentModuleMetadata ./.
├── config.nix                     # NCC: cfg = getModuleConfig moduleName
├── commands.nix                   # NCC Commands
├── api.nix                        # NCC API
└── submodules/                    # NCC Submodules: bekommen getCurrentModuleMetadata automatisch weitergegeben!
    ├── cli-formatter/             # Von system-manager verschoben
    │   ├── default.nix            # moduleName = baseNameOf ./.; _module.args.moduleName = moduleName;
    │   ├── options.nix            # getCurrentModuleMetadata ./.
    │   ├── config.nix             # cfg = getModuleConfig moduleName;
    │   └── api.nix                # API setzen
    ├── cli-registry/              # Von system-manager
    │   ├── default.nix            # GENAUSO WIE SYSTEM-MANAGER SUBMODULES!
    │   ├── options.nix            # GENAUSO!
    │   ├── config.nix             # GENAUSO!
    │   └── api.nix                # GENAUSO!
    └── cli-permissions/           # NEU: Permissions
        ├── default.nix            # GENAUSO!
        ├── options.nix            # GENAUSO!
        ├── config.nix             # GENAUSO!
        └── api.nix                # GENAUSO!
```

## Implementierung (EINFACH - GENAU WIE SYSTEM-MANAGER!)

### SCHRITTE:

1. **NCC zu core/default.nix hinzufügen** (wie system-manager)
2. **NCC default.nix erstellen** (genau wie system-manager/default.nix)
3. **cli-formatter & cli-registry verschieben** aus system-manager/submodules/ nach nixos-control-center/submodules/
4. **Pfade in Submodules anpassen** (system-manager.submodules.cli-formatter → nixos-control-center.submodules.cli-formatter)
5. **system-manager/default.nix bereinigen** (Imports entfernen)

### 1. NCC zu core/default.nix hinzufügen
```nix
imports = [
  ./base/boot
  ./base/hardware
  # ... andere
  ./management/system-manager      # Vorhanden
  ./management/module-manager      # Vorhanden
  ./management/nixos-control-center # NEU - GENAUSO WIE SYSTEM-MANAGER!
];
```

### 2. NCC default.nix erstellen (GENAU WIE SYSTEM-MANAGER!)
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  moduleName = baseNameOf ./. ;  # "nixos-control-center"
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "NixOS Control Center - CLI ecosystem";
    category = "management";
    subcategory = "control-center";
    stability = "stable";
    version = "1.0.0";
  };

  _module.args.moduleName = moduleName;

  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix
    ./api.nix
    # NCC importiert Submodules - GENAUSO WIE SYSTEM-MANAGER!
    ./submodules/cli-formatter    # VERSCHOBEN von system-manager
    ./submodules/cli-registry     # VERSCHOBEN von system-manager
    ./submodules/cli-permissions  # NEU
  ];
}
```

### 3. cli-formatter & cli-registry verschieben

**Einfach verschieben:**
- Von: `system-manager/submodules/cli-formatter/` → `nixos-control-center/submodules/cli-formatter/`
- Von: `system-manager/submodules/cli-registry/` → `nixos-control-center/submodules/cli-registry/`

**Pfade in Submodules anpassen:**
- `system-manager.submodules.cli-formatter` → `nixos-control-center.submodules.cli-formatter`
- `system-manager.submodules.cli-registry` → `nixos-control-center.submodules.cli-registry`

**Die Submodules bleiben GLEICH - keine Änderungen nötig!**

### 4. system-manager/default.nix bereinigen
```diff
 imports = [
   ./options.nix
   ./commands.nix
   ./config.nix
   # Import all submodules (full-featured modules within system-manager)
-  ./submodules/cli-formatter    # ← ENTFERNT - jetzt in nixos-control-center
-  ./submodules/cli-registry     # ← ENTFERNT - jetzt in nixos-control-center
   ./submodules/system-update    # System update submodule
   ./submodules/system-checks    # System validation submodule
   ./submodules/system-logging   # System logging submodule
   # Keep other handlers
   ./handlers/channel-manager.nix
 ];
```

## WARUM DAS FUNKTIONIERT (GENAU WIE SYSTEM-MANAGER!):

1. **NCC ist Core-Modul** → bekommt `getCurrentModuleMetadata` von flake.nix
2. **NCC importiert Submodules** → Args werden automatisch weitergegeben (wie bei system-manager!)
3. **Jeder Submodul macht `moduleName = baseNameOf ./.`** → wie system-manager Submodules
4. **Jeder Submodul setzt `_module.args.moduleName`** → wie system-manager Submodules
5. **Generisches Pattern** → KEINE hardcoded Pfade!

## Success Criteria

- ✅ NCC zu core/default.nix hinzugefügt (bekommt getCurrentModuleMetadata automatisch)
- ✅ NCC default.nix erstellt (genau wie system-manager)
- ✅ cli-formatter & cli-registry verschoben ohne Änderungen
- ✅ Pfade in Submodules angepasst
- ✅ system-manager bereinigt
- ✅ Build erfolgreich

*Das ist alles - einfach und sauber!* 🎯
