# 🗺️ NixOS Control Center - Module Management Roadmap

## 🎯 Central Module Activation/Deactivation System

### Overview
The Module Manager provides **central coordination** for module activation while **preserving manual control**. Users can still edit `system-config.nix` manually, but get optional GUI support and better module discovery. Zero-configuration for new modules with full backward compatibility.

### Why this change?
- **Current**: Manual activation in `system-config.nix` (`features.security.ssh-client-manager.enable = true;`)
- **Problem**: Hard to discover available modules, manual management
- **Goal**: Module Manager as central authority for module lifecycle, with optional GUI

---

## 🔍 Module Classification & Activation Strategy

### Current Module Structure Problem
**All modules** are currently manually activated in `system-config.nix`, but we need:
- Dynamic discovery of available modules
- Central activation/deactivation
- GUI for management
- Zero-configuration for new modules

### Module Categories & Activation Rules

**Foundation Modules (always active, not configurable):**
- `core/boot`, `core/hardware`, `core/user` - Absolute minimum for system boot

**System-Manager Submodules (integrated in system-manager):**
- `system-manager/submodules/cli-formatter` ← `core/infrastructure/cli-formatter/`
- `system-manager/submodules/cli-registry` ← `core/infrastructure/command-center/`
- `system-manager/submodules/system-update` ← (aus aktuellem system-manager/handlers/ extrahiert)
- `system-manager/submodules/system-checks` ← `core/management/checks/`
- `system-manager/submodules/system-logging` ← `core/management/logging/`

**Central Management Module:**
- `core/management/module-manager` - Module discovery & activation (can be disabled)

**Feature Modules (configurable via Module Manager):**
- `modules/security/*` - Security features (ssh-client, ssh-server, lock)
- `modules/infrastructure/*` - Infrastructure features (homelab, vm)
- `modules/specialized/*` - Specialized features (ai-workspace, hackathon)

### New Module Manager Architecture

**Central Configuration:**
```nix
# module-manager-config.nix - SINGLE SOURCE OF TRUTH
{
  # Core modules (implicitly always enabled)
  core = {
    enabled = true;  # Always true, not configurable
  };

  # Feature modules (configurable)
  features = {
    security."ssh-client-manager" = true;
    infrastructure.homelab-manager = false;
    infrastructure.vm-manager = true;
  };
}
```

**Module Manager Responsibilities:**
- Discover all available modules from filesystem
- Read central configuration
- Activate/deactivate modules accordingly
- Provide GUI for management
- Handle module dependencies

---

## 📋 Implementation Roadmap

### Phase 1: Foundation Architecture (2-3 days)

#### 1.1 Core Restructure
**Files**: `nixos/core/default.nix`, `nixos/modules/default.nix`
- Restructure core/ to keep system/ + management/ (with submodules)
- Create modules/ directory for feature domains (security/infrastructure/specialized)
- Update flake.nix to import both core/ and modules/

#### 1.2 System-Manager Submodule Integration
**Files**: `nixos/core/management/system-manager/default.nix`
- Convert checks/ and logging/ to submodules of system-manager
- Move cli-formatter/ and command-center/ as submodules
- Create unified CLI API through system-manager

#### 1.3 Module-Manager Enhancement
**File**: `nixos/core/management/module-manager/`
- Keep module-manager in core/ (as finalized)
- Implement dynamic filesystem discovery for modules/
- Create module registry with dependency resolution

### Phase 2: Dynamic Module System (3-4 days)

#### 2.1 Module Discovery Implementation
**File**: `nixos/core/management/module-manager/lib/discovery.nix`
- Automatic filesystem scanning of modules/
- Module metadata extraction (name, category, description, dependencies)
- Caching for performance
- Support for new module auto-registration

#### 2.2 Dynamic Import System
**Files**: `nixos/core/management/module-manager/` + `nixos/modules/default.nix`
- Module-manager reads discovery and generates dynamic imports
- Only import enabled modules from modules/
- Support for feature domains (security/infrastructure/specialized)
- Performance optimization through lazy loading

#### 2.3 Module Manager GUI
**File**: `nixos/core/management/module-manager/commands.nix`
- Interactive module manager (`ncc module-manager`)
- Shows all discovered modules with status
- Toggle modules on/off
- Search/filter functionality
- Dependency warnings and validation

### Phase 3: Advanced Features & Testing (3-4 days)

#### 3.1 Module Presets & Templates
- Predefined module combinations (desktop/server/development)
- Use case templates for different scenarios
- One-click activation of preset configurations

#### 3.2 Module Health Checks & Validation
- Verify module configurations before activation
- Dependency satisfaction checking
- Configuration validation and conflict detection

#### 3.3 Module Updates & Migration
- Automatic module version checking
- Migration assistance for breaking changes
- Update notifications and compatibility warnings

### Phase 4: Multi-Host Management & AI Features (2-3 days)

#### 4.1 Multi-Host Module Synchronization
- Cross-host module synchronization
- Environment-specific configurations
- Centralized management dashboard

#### 4.2 AI-Powered Module Discovery
- Natural language module discovery
- Intelligent suggestions based on use case
- Automated configuration recommendations

#### 4.3 Community Integration
- Home Manager module discovery
- External module repositories
- Community module marketplace

---

## 🏗️ Filesystem Structure Evolution

### Current Structure
```
nixos/
├── core/                    # Always active modules
├── features/               # Manually activated modules
└── flake.nix               # Static imports
```

### Target Structure (Phase 1 - FINAL)
```
# FINAL ARCHITECTURE

nixos/
├── core/                    # Foundation system (always active)
│   ├── system/  
│   │   ├── boot/           # Always (can't boot without)
│   │   ├── hardware/       # Always (kernel modules needed)  
│   │   ├── user/           # Always (can't login without)
│   │   ├── network/        # Always (updates need internet)
│   │   ├── packages/       # Always (basic tools needed)
│   │   ├── desktop/        # Always (GUI expected for desktop)
│   │   ├── audio/          # Always (multimedia expected)
│   │   └── localization/   # Always (international support)
│   ├── management/
│   │   ├── system-manager/    # Config-Management + CLI-APIs + Updates
│   │   │   ├── submodules/    # SUBMODULE CONTAINER (for scalability)
│   │   │   │   ├── cli-formatter/ # SUBMODULE: UI formatting
│   │   │   │   ├── cli-registry/  # SUBMODULE: CLI command registration (old command-center)
│   │   │   │   ├── system-update/ # SUBMODULE: update logic
│   │   │   │   ├── system-checks/ # SUBMODULE: system validation
│   │   │   │   └── system-logging/# SUBMODULE: system reports
│   │   │   ├── components/    # Small utilities
│   │   │   ├── handlers/      # Main orchestration
│   │   │   └── config.nix     # Main implementation
│   │   └── module-manager/   # Modul-Management (Discovery/Aktivierung)  
│   └── default.nix
├── modules/                 # Extended modules (configurable)
│   ├── security/           # Domain: Security
│   │   ├── ssh-client-manager/
│   │   ├── ssh-server-manager/
│   │   └── lock-manager/
│   ├── infrastructure/     # Domain: Infrastructure (Features)
│   │   ├── homelab-manager/
│   │   └── vm-manager/
│   └── specialized/        # Domain: Specialized
│       ├── ai-workspace/
│       └── hackathon/
└── flake.nix
```

**Why static imports for features?**
- ✅ **Performance:** Faster than dynamic path generation
- ✅ **Simple:** Nix-compatible, no complex dynamics
- ✅ **Functional:** Features use `mkIf cfg.enable` → only enabled ones run
- ✅ **Flexible:** New features placed in FS, auto-discovered
- ⚠️ **Issue:** Broken imports when folders deleted

**How does the "dynamic" behavior work?**
1. `features/default.nix` imports ALL features statically
2. Each feature checks `mkIf cfg.enable` (lazy evaluation)
3. `module-manager` sets `cfg.enable` dynamically from config
4. **Result:** Only enabled features actually execute!

**Safe imports for deleted folders:**
```nix
# features/default.nix uses automatic discovery:
imports = lib.map (name:
  ./. + "/${name}"
) (lib.attrNames (lib.filterAttrs (name: type:
  type == "directory" && builtins.pathExists (./. + "/${name}/default.nix")
) (builtins.readDir ./.)))
```
→ **Only existing modules are imported!**

**Implementation approach:**
`module-manager/lib/discovery.nix` provides `safeFeatureImports` helper function. `features/default.nix` uses this function directly.

**Warum KEIN extra "modules/" Ordner?**
- Zu viel Umstrukturierung
- Bestehende Struktur funktioniert gut
- core/ bleibt für immer-aktive Module
- features/ für konfigurierbare Module
- module-manager erweitert bestehende Struktur

---

## 🔄 Module Activation Workflow

### Current Manual Process:
1. User finds module in docs
2. Manually adds to `system-config.nix`
3. Runs `sudo nixos-rebuild switch`
4. Module becomes active

### New Automated Process:
1. User runs `ncc module-manager`
2. GUI shows all available modules
3. User toggles desired modules
4. Module-manager updates config
5. Automatic system rebuild
6. Modules activated/deactivated

### Advanced Workflow (Future):
1. User describes need: "I want SSH management"
2. System suggests `ssh-client-manager`
3. Auto-resolves dependencies
4. One-click activation
5. Self-documenting system

---

## 📊 Module State Management

### Module States:
- **Core**: Always enabled (not in config)
- **Enabled**: Active and configured
- **Disabled**: Available but inactive
- **Missing**: Not installed/discovered

### Configuration Sources:
1. **module-manager-config.nix**: User preferences
2. **Module defaults**: Fallback values
3. **Dependency resolution**: Automatic activation
4. **System requirements**: Hardware/driver based

### State Persistence:
- Configuration survives rebuilds
- Backup/restore functionality
- Version control integration
- Migration between versions

---

## 🎯 Success Criteria

### Functional Requirements:
- [ ] All modules discoverable automatically
- [ ] Manual config editing remains possible (Primary)
- [ ] GUI for module management (Optional)
- [ ] Zero-config for new modules
- [ ] Dependency resolution
- [ ] Safe activation/deactivation

### User Experience:
- [ ] Intuitive GUI navigation
- [ ] Clear module descriptions
- [ ] Fast search/filtering
- [ ] Helpful dependency warnings
- [ ] One-click activation

### Technical Requirements:
- [ ] Efficient discovery (cached)
- [ ] Safe rebuild process
- [ ] Rollback capability
- [ ] Comprehensive testing
- [ ] Documentation complete

---

## 📅 Final Implementation Timeline

| Phase | Duration | Focus |
|-------|----------|--------|
| Phase 1 | 2-3 days | Foundation architecture & submodule integration |
| Phase 2 | 3-4 days | Dynamic module system & GUI |
| Phase 3 | 3-4 days | Advanced features & validation |
| Phase 4 | 2-3 days | Multi-host & AI features |

**Total: ~10-14 days** (final timeline)

---

## 🚀 Future Extensions

### AI-Powered Features:
- Natural language module discovery
- Intelligent suggestions
- Automated configuration

### Multi-Host Management:
- Cross-host module synchronization
- Environment-specific configurations
- Centralized management dashboard

### Integration Features:
- Home Manager module discovery
- External module repositories
- Community module marketplace

---

## ⚠️ Risks & Mitigation

### Discovery Performance:
- **Risk**: Slow system on many modules
- **Mitigation**: Caching, lazy loading, background discovery

### Breaking Changes:
- **Risk**: Existing configurations break
- **Mitigation**: Migration scripts, backward compatibility

### User Confusion:
- **Risk**: Too many options overwhelm users
- **Mitigation**: Guided workflows, presets, progressive disclosure

---

## ✅ Benefits Summary

### For Users:
- **Discoverability**: Find modules easily
- **Simplicity**: GUI instead of config editing
- **Safety**: Guided activation with dependency checking
- **Flexibility**: Enable/disable without rebuild knowledge

### For Developers:
- **Modularity**: Clean module boundaries
- **Testability**: Isolated module testing
- **Maintainability**: Central management logic
- **Extensibility**: Easy addition of new modules

### For System:
- **Reliability**: Consistent activation patterns
- **Performance**: Optimized loading
- **Scalability**: Handles hundreds of modules
- **Future-proof**: Adaptable architecture

---

*This roadmap transforms the module system from manual configuration management to intelligent, user-friendly module lifecycle management.*
