# 🏗️ NixOS Control Center - Module Restructure Implementation Plan

## 🎯 Overview
Complete the foundation architecture restructure by moving infrastructure components into system-manager as submodules and creating the modules/ directory structure based on the final architecture.

## 📋 Phase 1: Foundation Architecture Implementation

### 1.1 Create modules/ Directory Structure
**Status:** Ready to implement

**Correct Final Structure from ROADMAP_0.md:**

**CORE (always active):**
```
nixos/core/management/
├── system-manager/          # System management with submodules (MOVED HERE)
│   ├── submodules/          # SUBMODULE CONTAINER (for scalability)
│   │   ├── cli-formatter/   # SUBMODULE: UI formatting (MOVED FROM infrastructure/)
│   │   ├── cli-registry/    # SUBMODULE: CLI command registration (MOVED FROM infrastructure/, renamed)
│   │   ├── system-update/   # SUBMODULE: update logic (EXTRACTED from handlers/)
│   │   ├── system-checks/   # SUBMODULE: system validation (MOVED FROM management/)
│   │   └── system-logging/  # SUBMODULE: system reports (MOVED FROM management/)
│   ├── components/          # Small utilities
│   ├── handlers/            # Main orchestration
│   └── config.nix           # Main implementation
└── module-manager/          # Module discovery & activation (STAYS HERE)
```

**MODULES (configurable):**
```
nixos/modules/
├── security/               # Security domain
├── infrastructure/         # Infrastructure domain
└── specialized/            # Specialized domain
```

**Tasks:**
- [ ] Create `nixos/modules/` directory
- [ ] Create `nixos/modules/default.nix` with safe dynamic imports (module-manager handles activation)
- [ ] Create domain directories: `security/`, `infrastructure/`, `specialized/`
- [ ] **module-manager stays in core/management/module-manager/** (no change)
- [ ] **system-manager stays in core/management/system-manager/** (no change)

### 1.2 Move Infrastructure Modules to system-manager Submodules
**Status:** Ready to implement

**Migration Map (from ROADMAP_0.md):**
```
FROM: nixos/core/infrastructure/cli-formatter/
TO:   nixos/core/management/system-manager/submodules/cli-formatter/

FROM: nixos/core/infrastructure/command-center/
TO:   nixos/core/management/system-manager/submodules/cli-registry/
```

**Tasks:**
- [ ] Move `cli-formatter/` from `core/infrastructure/` to `core/management/system-manager/submodules/`
- [ ] Move `command-center/` from `core/infrastructure/` to `core/management/system-manager/submodules/` and rename to `cli-registry/`
- [ ] Update all internal references in moved modules

### 1.3 Move Management Modules to system-manager Submodules
**Status:** Ready to implement

**Migration Map:**
```
FROM: nixos/core/management/checks/
TO:   nixos/core/management/system-manager/submodules/system-checks/

FROM: nixos/core/management/logging/
TO:   nixos/core/management/system-manager/submodules/system-logging/

FROM: nixos/core/management/system-manager/handlers/system-update.nix
TO:   nixos/core/management/system-manager/submodules/system-update/
      ├── default.nix          # Submodule imports
      ├── options.nix          # Update-specific options
      ├── config.nix           # Update implementation
      ├── system-update-config.nix  # User config template
      └── handlers/
          └── system-update.nix # Extracted handler logic
```

**Tasks:**
- [ ] Move `checks/` from `core/management/` to `core/management/system-manager/submodules/` and rename to `system-checks/`
- [ ] Move `logging/` from `core/management/` to `core/management/system-manager/submodules/` and rename to `system-logging/`
- [ ] Convert `system-update.nix` handler to full submodule:
  - [ ] Create `submodules/system-update/options.nix` with update-specific options (backup settings, auto-build, update sources)
  - [ ] Create `submodules/system-update/config.nix` with implementation logic
  - [ ] Create `submodules/system-update/system-update-config.nix` user config template
  - [ ] Extract handler logic to `submodules/system-update/handlers/system-update.nix`
  - [ ] Create `submodules/system-update/default.nix` for submodule structure

### 1.4 Update system-manager as Submodule Container
**Status:** Ready to implement

**Create:** `nixos/modules/system-manager/README.md` to explain the structure

**README.md content:**
```markdown
# System Manager

The system-manager is a container module that provides core system management functionality through specialized submodules.

## Architecture

This module uses a **submodule architecture** where complex features are implemented as full submodules within the main module.

### Directory Structure

```
system-manager/
├── README.md              # This file
├── default.nix            # Main module imports
├── options.nix            # System-manager options
├── config.nix             # Main implementation
├── cli-formatter/         # SUBMODULE: CLI output formatting
├── cli-registry/          # SUBMODULE: CLI command management
├── system-update/         # SUBMODULE: System update functionality
├── system-checks/         # SUBMODULE: System validation
└── system-logging/        # SUBMODULE: System reporting
```

### Submodules vs Components

- **Submodules** (folders): Full-featured modules with their own config, options, and APIs
- **Components** (would be in components/): Small utility functions, no user configuration

## Submodule APIs

Each submodule exposes its own API:
- `config.system-manager.cli-formatter.*`
- `config.system-manager.cli-registry.*`
- etc.
```
**Status:** Ready to implement

**File:** `nixos/core/management/system-manager/default.nix`

**Changes:**
```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.core.management.system-manager or {};
in {
  imports = [
    ./options.nix
    # Import all submodules (full-featured modules within system-manager)
    ./submodules/cli-formatter    # CLI formatting submodule
    ./submodules/cli-registry     # CLI command registration submodule
    ./submodules/system-update    # System update submodule
    ./submodules/system-checks    # System validation submodule
    ./submodules/system-logging   # System logging submodule
  ] ++ (if (cfg.enable or true) then [
    ./config.nix  # Main system-manager implementation
  ] else []);
}
```

### 1.5 Update API References Throughout System
**Status:** Analysis needed

**Critical Breaking Changes:**
- `config.core.cli-formatter.*` → `config.modules.system-manager.cli-formatter.*`
- `config.core.command-center.*` → `config.modules.system-manager.cli-registry.*`

**Find affected files:**
```bash
grep -r "config\.core\.cli-formatter" nixos/
grep -r "config\.core\.command-center" nixos/
```

**Tasks:**
- [ ] Update all references in feature modules
- [ ] Update system-manager references
- [ ] Test that APIs still work

### 1.6 Update modules/default.nix
**Status:** Ready to implement

**File:** `nixos/modules/default.nix`

**Create with FULLY AUTOMATIC discovery:**
```nix
{ lib, ... }:

# FULLY AUTOMATIC module discovery
# Discovers ALL module directories automatically
# No hardcoded domain names!

let
  # Get all subdirectories that have default.nix
  discoveredModules = lib.filterAttrs (name: type:
    type == "directory" &&
    name != ".git" &&
    name != ".github" &&
    builtins.pathExists (./. + "/${name}/default.nix")
  ) (builtins.readDir ./.);

in {
  # Import ALL discovered module directories automatically
  imports = lib.mapAttrsToList (name: _type:
    ./. + "/${name}"
  ) discoveredModules;
}
```

**Result: FULLY AUTOMATIC HIERARCHY DISCOVERY**

#### **What gets discovered automatically:**
- ✅ **Domain Level**: `modules/security/`, `modules/infrastructure/`, etc.
- ✅ **Module Level**: `modules/security/ssh-client-manager/`
- ✅ **Submodule Level**: `modules/security/ssh-client-manager/handlers/`
- ✅ **Config Level**: Auto-generates `ssh-client-manager-config.nix`

#### **Endless Scalability Pattern:**
```
modules/
├── security/                    # Domain (auto-discovered)
│   ├── ssh-client-manager/      # Module (auto-discovered)
│   │   ├── default.nix         # Auto-imports submodules
│   │   ├── options.nix         # Auto-generates API paths
│   │   ├── config.nix          # Implementation
│   │   ├── handlers/           # Submodules (auto-discovered)
│   │   ├── scripts/            # Submodules (auto-discovered)
│   │   └── ssh-client-manager-config.nix  # Auto-generated
│   └── lock-manager/            # Another module (auto-discovered)
└── gaming/                      # New domain (auto-discovered)
    └── steam-manager/           # New module (auto-discovered)
        └── ...                  # Endless nesting possible
```

#### **Who does what:**

**modules/default.nix:**
- ✅ Discovers ALL domain folders automatically
- ✅ No hardcoded domain names
- ✅ Scales to unlimited domains

**Domain default.nix (e.g. modules/security/default.nix):**
- ✅ Discovers ALL modules in that domain
- ✅ Auto-generates module APIs
- ✅ Handles module activation

**Module default.nix (e.g. modules/security/ssh-client-manager/default.nix):**
- ✅ **SAFE STATIC IMPORTS** from submodules/ folder
- ✅ Imports: ./submodules/submodule-a, ./submodules/submodule-b, etc.
- ✅ No discovery logic - just safe imports

**Module-Manager:**
- ✅ **ORCHESTRATES** the entire discovery system
- ✅ Decides which modules get activated
- ✅ Manages dependencies between modules
- ✅ Generates APIs automatically

#### **Fully Generic - Zero Hardcoding:**
```nix
# modules/default.nix - FULL AUTO
discoveredModules = lib.filterAttrs (name: type:
  type == "directory" && builtins.pathExists (./. + "/${name}/default.nix")
) (builtins.readDir ./.);

imports = lib.mapAttrsToList (name: _type:
  ./. + "/${name}"  # AUTO IMPORT - any folder with default.nix
) discoveredModules;

# Result: Drop ANY folder → automatically discovered & imported
# No template changes needed, no hardcoded names, endless scalability
```


### 1.7 Update flake.nix with SAFE imports
**Status:** Ready to implement

**File:** `nixos/flake.nix`

**Changes - SAFE IMPORT (doesn't break if modules/ doesn't exist):**
```diff
-      ./core
-      ./features
+      ./core
+      # Safe import: only import modules/ if it exists
+      (if builtins.pathExists ./modules/default.nix then ./modules else {})
```

### 1.7 Test Complete Restructure
**Status:** Ready after implementation

**Tasks:**
- [ ] Test NixOS build with new structure
- [ ] Verify CLI commands work (`ncc`, `nixcc`, etc.)
- [ ] Test module discovery in modules/
- [ ] Verify no broken imports
- [ ] Test API changes work correctly

## 📅 Implementation Order

1. **Create directory structure** (1.1)
2. **Move infrastructure modules** (1.2)
3. **Move management modules** (1.3)
4. **Update system-manager** (1.4)
5. **Update flake.nix** (1.6)
6. **Update API references** (1.5)
7. **Test everything** (1.7)

## ⚠️ Risk Mitigation

### API Breaking Changes
- **High Risk:** Many modules use cli-formatter and command-center APIs
- **Mitigation:** Update all references systematically
- **Testing:** Verify each API still works

### Module Discovery
- **Risk:** modules/ not properly imported
- **Mitigation:** Test imports thoroughly
- **Fallback:** Manual verification

### Core Functionality
- **Risk:** CLI commands break
- **Mitigation:** Test all commands before/after
- **Rollback:** Keep backup of working structure

## ✅ Success Criteria

- [ ] NixOS builds successfully
- [ ] All CLI commands work
- [ ] Modules in modules/ are discoverable
- [ ] API paths updated correctly
- [ ] User configs created automatically
- [ ] No functionality regressions

## 🚀 Next Steps

After Phase 1 completion:
- **Phase 2:** Implement module-manager discovery
- **Phase 3:** Add GUI and advanced features
- **Phase 4:** Multi-host and AI features

---

*Implementation plan based on final ROADMAP_0.md architecture.*
