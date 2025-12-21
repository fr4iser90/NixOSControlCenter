# NixOS Control Center - Architecture Implementation Plan

## Executive Summary

Based on the fundamental architecture analysis, this implementation plan addresses the key issues:

1. **NCC System Module Creation** - Separate CLI ecosystem from system management
2. **Formatting Migration** - Move CLI formatting to dedicated NCC module
3. **Validated Module Discovery** - Add validation during module discovery phase
4. **Enhanced Validation Pipeline** - Coordinate validation between System and Module managers
5. **Domain Layer Evaluation** - Assess impact of removing rigid domain structure

## Implementation Phases

### Phase 1: NCC System Module Foundation (2-3 days)

#### 1.1 Create NCC Module Structure
**Objective:** Establish the new NCC system module with proper metadata and API structure.

**Files to Create:**
```
core/management/nixos-control-center/
├── default.nix              # Main NCC module definition
├── options.nix              # NCC configuration options
├── config.nix               # NCC implementation
├── commands.nix             # NCC command registration
├── api.nix                  # Public NCC APIs for other modules
└── submodules/
    ├── cli-formatter/       # MOVED from system-manager/submodules/cli-formatter/
    │   ├── default.nix
    │   ├── colors.nix
    │   ├── core.nix
    │   └── status.nix
    └── cli-registry/         # MOVED from system-manager/submodules/cli-registry/
        ├── default.nix
        ├── api.nix
        └── commands.nix
```

**Implementation Steps:**
1. Create directory structure
2. Copy cli-formatter from system-manager to ncc/submodules/
3. Update metadata and module structure following MODULE_TEMPLATE.md
4. Create basic API exports for formatting and registry

#### 1.2 Update Core Imports
**Objective:** Add NCC module to core/default.nix

**Files to Modify:**
- `nixos/core/default.nix`

**Changes:**
```nix
imports = [
  # Core system modules
  ./base/boot
  ./base/hardware
  ./base/network
  ./base/localization
  ./base/user
  ./base/desktop
  ./base/audio
  ./base/packages
  # Management (includes infrastructure as submodules)
  ./management/system-manager
  ./management/module-manager
  ./management/nixos-control-center             # CLI ecosystem (NEW)
];
```

#### 1.3 NCC Module Definition
**File:** `nixos/core/management/ncc/default.nix`
```nix
{ config, lib, pkgs, systemConfig, ... }:

let
  # Module metadata (REQUIRED - define directly here)
  metadata = {
    # Basic info
    name = "ncc";
    scope = "system";          # system | shared | user
    mutability = "overlay";    # exclusive | overlay
    dimensions = [];           # [] for system scope, ["user"] for shared
    description = "NixOS Control Center - CLI ecosystem";
    version = "1.0.0";
  };
in {
  # REQUIRED: Export metadata for discovery system
  _module.metadata = metadata;

  # Module imports
  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix
    ./api.nix
    ./submodules/cli-formatter
    ./submodules/cli-registry
  ];
}
```

#### 1.4 NCC API Definition
**File:** `nixos/core/management/ncc/api.nix`
```nix
{ config, lib, ... }:

with lib;

let
  # Import formatting APIs
  formatter = config.core.management.ncc.submodules.cli-formatter.api;
  registry = config.core.management.ncc.submodules.cli-registry.api;
in {
  # Public NCC API - available to all modules
  core.management.ncc.api = {
    inherit formatter registry;

    # Convenience functions
    format = formatter;
    registerCommand = registry.register;
  };
}
```

### Phase 2: Formatting Migration (1-2 days)

#### 2.1 Update System Manager Commands
**Objective:** Change system-manager to use NCC formatting API instead of direct imports

**Files to Modify:**
- `nixos/core/management/system-manager/commands.nix`

**Changes:**
```nix
# BEFORE: Direct imports
colors = import ./submodules/cli-formatter/colors.nix;
coreFormatter = import ./submodules/cli-formatter/core { inherit lib colors; config = {}; };
statusFormatter = import ./submodules/cli-formatter/status { inherit lib colors; config = {}; };

# AFTER: Use NCC API
formatter = config.core.management.ncc.api.formatter;
colors = formatter.colors;
coreFormatter = formatter.core;
statusFormatter = formatter.status;
```

#### 2.2 Update Module Manager Commands
**Objective:** Update module-manager to use NCC formatting API

**Files to Modify:**
- `nixos/core/management/module-manager/commands.nix`

**Changes:**
```nix
# BEFORE: Direct system-manager reference
ui = config.core.management.system-manager.submodules.cli-formatter.api;

# AFTER: Use NCC API
ui = config.core.management.ncc.api.formatter;
```

#### 2.3 Remove Old CLI Formatter from System Manager
**Objective:** Remove the old cli-formatter submodule from system-manager

**Files to Modify:**
- `nixos/core/management/system-manager/default.nix`
- Remove cli-formatter references from imports and config

#### 2.4 Update Flake.nix
**Objective:** Ensure NCC module is properly imported in flake structure

**Files to Modify:**
- `nixos/flake.nix`

**Verification:**
- Test that all NCC commands still work
- Verify formatting consistency across modules

### Phase 3: Validated Module Discovery (2-3 days)

#### 3.1 Create Discovery Validation Library
**Objective:** Implement module validation during discovery phase

**Files to Create:**
```
core/management/module-manager/lib/
├── discovery.nix           # Enhanced discovery with validation
├── validation.nix          # Module structure validation
└── metadata.nix            # Metadata processing utilities
```

**Implementation:**
```nix
# lib/discovery.nix - Enhanced discovery with validation
{ lib, ... }:

let
  validateModule = modulePath: {
    hasDefault = builtins.pathExists (modulePath + "/default.nix");
    hasMetadata = hasDefault && ((import modulePath)._module.metadata or null) != null;
    isValid = hasDefault && hasMetadata;
  };

  discoverModules = basePath:
    let
      entries = lib.filterAttrs (name: type: type == "directory") (builtins.readDir basePath);
      validatedModules = lib.mapAttrs (name: _: validateModule (basePath + "/${name}")) entries;
      validModules = lib.filterAttrs (name: validation: validation.isValid) validatedModules;
    in
    lib.attrNames validModules;
in {
  inherit discoverModules validateModule;
}
```

#### 3.2 Update Module Manager Config
**Objective:** Integrate validated discovery into module manager

**Files to Modify:**
- `nixos/core/management/module-manager/config.nix`

**Changes:**
- Import new discovery library
- Replace simple directory scanning with validated discovery
- Add error reporting for invalid modules

#### 3.3 Add Discovery Commands
**Objective:** Add CLI commands to validate and report module status

**Files to Modify:**
- `nixos/core/management/module-manager/commands.nix`

**New Commands:**
- `ncc module-manager validate-modules` - Check all modules for validity
- `ncc module-manager list-invalid` - Show modules that failed validation

### Phase 4: Enhanced Validation Pipeline (1-2 days)

#### 4.1 Extend NCC with Validation APIs
**Objective:** Add validation coordination to NCC as CLI infrastructure

**Files to Modify:**
- `core/management/nixos-control-center/api.nix` - Add validation APIs

**New NCC Validation APIs:**
```nix
core.management.ncc.api = {
  inherit formatter registry;

  # Validation APIs
  validation = {
    validateModule = moduleName: { /* validation logic */ };
    validateSystem = { /* system checks */ };
    checkDependencies = moduleList: { /* dependency resolution */ };
    reportIssues = issues: { /* NCC-formatted error reporting */ };
  };
};
```

#### 4.2 System Manager Validation Enhancement
**Objective:** Make system manager use NCC validation APIs

**Files to Modify:**
- `nixos/core/management/system-manager/submodules/system-checks/`

**Changes:**
- Use `config.core.management.ncc.api.validation` instead of local logic
- Format validation reports with NCC formatter

#### 4.3 Module Manager Validation Enhancement
**Objective:** Integrate module manager with NCC validation

**Files to Modify:**
- `nixos/core/management/module-manager/handlers/module-manager.nix`

**Changes:**
- Use NCC validation APIs for dependency checking
- Report validation results through NCC formatting

### Phase 5: Domain Layer Assessment (1-2 days)

#### 5.1 Analyze Current Domain Usage
**Objective:** Assess impact of domain removal

**Analysis Tasks:**
1. Map all current modules to domains
2. Identify cross-domain dependencies
3. Survey user expectations for organization
4. Evaluate metadata-driven alternatives

#### 5.2 Create Migration Path
**Objective:** Plan domain layer removal if beneficial

**Files to Create:**
- `docs/migration/domain-removal-plan.md`

**Migration Strategy:**
1. Add metadata fields to all modules
2. Implement metadata-driven discovery
3. Update documentation and examples
4. Provide migration script for users

#### 5.3 Implement Metadata-Driven Discovery (Optional)
**Objective:** If domains are removed, implement flexible categorization

**Files to Modify:**
- `core/management/module-manager/lib/discovery.nix`

**Implementation:**
```nix
# Metadata-driven grouping
groupByCategory = modules:
  lib.groupBy (module: module._module.metadata.category or "uncategorized") modules;
```
## Success Criteria

### Functional Requirements
- [ ] NCC module provides formatting API to all modules
- [ ] Module discovery validates module structure
- [ ] Validation coordinator prevents invalid configurations
- [ ] System and Module managers coordinate properly
- [ ] CLI commands work with new architecture

### Quality Requirements
- [ ] All existing functionality preserved
- [ ] No breaking changes without migration path
- [ ] Comprehensive test coverage
- [ ] Updated documentation

### Performance Requirements
- [ ] Module discovery time < 2 seconds
- [ ] Validation overhead < 10% of build time
- [ ] CLI responsiveness maintained

## Timeline and Milestones

| Phase | Duration | Milestone |
|-------|----------|-----------|
| Phase 1: NCC Foundation | 2-3 days | NCC module created and integrated |
| Phase 2: Formatting Migration | 1-2 days | All modules use NCC formatting |
| Phase 3: Validated Discovery | 2-3 days | Module validation during discovery |
| Phase 4: Validation Pipeline | 2-3 days | Centralized validation coordination |

**Total Timeline:** 11-17 days

## Dependencies and Prerequisites

### Required Knowledge
- Nix language and NixOS module system
- Current system-manager and module-manager architecture
- CLI command structure and registry system

### Tools and Environment
- NixOS development environment
- Access to test systems for validation
- Version control for safe rollbacks

### Pre-Implementation Checklist
- [ ] All current tests passing
- [ ] Backup of current working configuration
- [ ] Review of MODULE_TEMPLATE.md compliance
- [ ] Documentation of current CLI command structure

## Next Steps

1. **Immediate:** Review and approve implementation plan
2. **Week 1:** Start Phase 1 (NCC module creation)
3. **Ongoing:** Regular testing and validation checkpoints
4. **Final:** Production deployment with monitoring

---

*This implementation plan transforms the architecture from scattered concerns to a well-organized, maintainable system with clear separation of responsibilities.*
