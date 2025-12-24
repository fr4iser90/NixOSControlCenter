# NixOS Control Center - GENERISCHE Architecture Implementation Plan

## Executive Summary

**REVOLUTIONÄRE GENERISCHE ARCHITEKTUR!** Basierend auf der komplett generischen Core-Architektur implementiert dieser Plan:

1. **🧬 GENERISCHE NCC-STRUKTUR** - NCC als generisches Discovery-Modul
2. **🎨 GENERISCHE FORMATTER-MIGRATION** - CLI-Formatting mit generischen APIs
3. **🔐 GENERISCHE PERMISSION-SYSTEM** - Rollenbasierte Zugriffe generisch
4. **✅ GENERISCHE VALIDATION** - Modul-Validation während Discovery
5. **🔗 GENERISCHE VALIDATION-PIPELINE** - Koordinierte Validation zwischen Modulen
6. **🏗️ GENERISCHE DOMAIN-ARCHITEKTUR** - Flexible Kategorisierung durch Metadata

**SCHLÜSSEL-PRINZIP: ALLES GENERISCH - KEINE HARDCODINGS!**

## Implementation Phases

### Phase 1: GENERISCHE NCC-STRUKTUR (2-3 Tage)

#### 1.1 GENERISCHE NCC-Modul-Struktur Erstellen
**Ziel:** NCC als vollständig generisches Discovery-Modul etablieren.

**GENERISCHE Dateien-Struktur:**
```bash
# ALLE Module folgen dem EXAKTEN generischen Pattern!
core/management/nixos-control-center/
├── default.nix                    # GENERISCH: moduleName = baseNameOf ./.
├── options.nix                    # GENERISCH: getCurrentModuleMetadata ./.
├── config.nix                     # GENERISCH: { ..., moduleName }: cfg = getModuleConfig moduleName
├── commands.nix                   # NCC-spezifische Commands
├── api.nix                        # GENERISCHE API-Exports
└── submodules/
    ├── cli-formatter/             # VERSCHOBEN von system-manager
    │   ├── default.nix            # GENERISCH: baseNameOf ./. Pattern
    │   ├── api.nix                # GENERISCHE API-Definition
    │   ├── options.nix            # GENERISCH: getCurrentModuleMetadata
    │   ├── config.nix             # GENERISCH: moduleName Parameter
    │   ├── colors.nix             # Implementation-Details
    │   ├── core.nix               # Implementation-Details
    │   ├── status.nix             # Implementation-Details
    │   └── cli-formatter-config.nix # User-Template (NICHT generisch)
    ├── cli-registry/              # NEUES: Command-Registrierung
    │   ├── default.nix            # GENERISCH: baseNameOf ./. Pattern
    │   ├── api.nix                # GENERISCHE API-Definition
    │   ├── options.nix            # GENERISCH: getCurrentModuleMetadata
    │   ├── config.nix             # GENERISCH: moduleName Parameter
    │   ├── commands.nix           # Command-Registrierung
    │   ├── filter.nix             # Permission-Filtering
    │   └── cli-registry-config.nix # User-Template (NICHT generisch)
    └── cli-permissions/           # NEUES: Rollenbasierte Zugriffe
        ├── default.nix            # GENERISCH: baseNameOf ./. Pattern
        ├── api.nix                # GENERISCHE API-Definition
        ├── options.nix            # GENERISCH: getCurrentModuleMetadata
        ├── config.nix             # GENERISCH: moduleName Parameter
        ├── roles.nix              # Permission-Rollen
        ├── policies.nix           # Permission-Policies
        ├── access-control.nix     # Zugriffs-Kontrolle
        ├── user-context.nix       # User-Erkennung
        └── cli-permissions-config.nix # User-Template (NICHT generisch)
```

**GENERISCHE Implementierungs-Schritte:**
1. **Directory-Struktur erstellen** mit generischen Submodulen
2. **cli-formatter von system-manager nach ncc/submodules/cli-formatter/ verschieben**
3. **cli-registry Submodul mit generischer Command-Registrierung erstellen**
4. **cli-permissions Submodul mit generischer rollenbasierter Zugriffs-Kontrolle erstellen**
5. **Metadata in ALLEN Submodulen aktualisieren** mit generischen Patterns
6. **GENERISCHE API-Exports** mit `getModuleApi` System

#### 1.2 GENERISCHE Core-Imports Aktualisieren
**Ziel:** NCC-Modul zu core/default.nix hinzufügen mit generischer Struktur.

**Dateien modifizieren:**
- `nixos/core/default.nix`

**GENERISCHE Änderungen:**
```nix
imports = [
  # GENERISCHE Core system modules (alle discovery-basiert!)
  ./base/boot        # moduleName = baseNameOf ./.
  ./base/hardware    # moduleName = baseNameOf ./.
  ./base/network     # moduleName = baseNameOf ./.
  ./base/localization # moduleName = baseNameOf ./.
  ./base/user        # moduleName = baseNameOf ./.
  ./base/desktop     # moduleName = baseNameOf ./.
  ./base/audio       # moduleName = baseNameOf ./.
  ./base/packages    # moduleName = baseNameOf ./.

  # GENERISCHE Management (alle submodules generisch)
  ./management/system-manager    # moduleName = baseNameOf ./.
  ./management/module-manager    # moduleName = baseNameOf ./.
  ./management/nixos-control-center # GENERISCHES NCC (NEU!) moduleName = baseNameOf ./.
];
```

#### 1.3 GENERISCHE NCC-Modul-Definition
**Datei:** `nixos/core/management/nixos-control-center/default.nix`
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # GENERISCH: Modulname aus Dateisystem ableiten
  moduleName = baseNameOf ./. ;  # "nixos-control-center"

  cfg = getModuleConfig moduleName;
in {
  # GENERISCH: Metadata aus generischem Pattern
  _module.metadata = {
    role = "core";
    name = moduleName;  # ← GENERISCH!
    description = "NixOS Control Center - CLI ecosystem";
    category = "management";
    subcategory = "control-center";
    stability = "stable";
    version = "1.0.0";
  };

  # GENERISCH: Modulname weitergeben
  _module.args.moduleName = moduleName;

  # GENERISCHE Imports (alle Submodule generisch!)
  imports = if cfg.enable or true then [
    ./options.nix
    ./config.nix
    ./commands.nix
    ./api.nix
  ] else [];
}
```

#### 1.4 GENERISCHE NCC-API-Definition
**Datei:** `nixos/core/management/nixos-control-center/api.nix`
```nix
{ config, lib, getModuleApi, ... }:

with lib;

let
  # GENERISCH: APIs über getModuleApi laden (NICHT hardcoded!)
  formatter = config.${getModuleApi "cli-formatter"};
  registry = config.${getModuleApi "cli-registry"};
  permissions = config.${getModuleApi "cli-permissions"};
in {
  # GENERISCHE Public NCC API - für alle Module verfügbar
  core.management.nixos-control-center.api = {
    inherit formatter registry permissions;

    # GENERISCHE Convenience functions
    format = formatter;
    registerCommand = registry.register;
  };
}
```

### Phase 2: GENERISCHE Formatter-Migration (1-2 Tage)

#### 2.1 GENERISCHE System-Manager Commands Aktualisieren
**Ziel:** system-manager soll NCC formatting API verwenden statt direkter Imports

**Dateien modifizieren:**
- `nixos/core/management/system-manager/commands.nix`

**GENERISCHE Änderungen:**
```nix
# VORHER: Direkte hardcoded Imports (NICHT GENERISCH!)
colors = import ./submodules/cli-formatter/colors.nix;
coreFormatter = import ./submodules/cli-formatter/core { inherit lib colors; config = {}; };
statusFormatter = import ./submodules/cli-formatter/status { inherit lib colors; config = {}; };

# NACHHER: GENERISCHE API-System verwenden
formatter = config.${getModuleApi "cli-formatter"};  # ← GENERISCH!
colors = formatter.colors;
coreFormatter = formatter.core;
statusFormatter = formatter.status;
```

#### 2.2 GENERISCHE Module-Manager Commands Aktualisieren
**Ziel:** module-manager soll NCC formatting API verwenden

**Dateien modifizieren:**
- `nixos/core/management/module-manager/commands.nix`

**GENERISCHE Änderungen:**
```nix
# VORHER: Direkte system-manager Referenz (hardcoded)
# NACHER: Build-time Access beibehalten (context-appropriate)
ui = getModuleApi "cli-formatter";  # ← GLEICH BLEIBEN (bereits generisch)
```

#### 2.3 GENERISCHE CLI-Formatter von System-Manager Entfernen
**Ziel:** Alten cli-formatter Submodul aus system-manager entfernen

**Dateien modifizieren:**
- `nixos/core/management/system-manager/default.nix` (GENERISCH!)
- cli-formatter Referenzen aus imports und config entfernen

#### 2.4 GENERISCHE Flake.nix Aktualisieren
**Ziel:** NCC-Modul korrekt in flake Struktur importieren

**Dateien modifizieren:**
- `nixos/flake.nix`

**Verifikation:**
- ✅ Alle NCC-Commands funktionieren noch
- ✅ Formatting-Konsistenz über alle Module
- ✅ GENERISCHE APIs werden korrekt verwendet

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
core.management.nixos-control-center.api = {
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
- Use `config.${getModuleApi "nixos-control-center"}.validation` instead of local logic
- Format validation reports with NCC formatter

#### 4.3 Module Manager Validation Enhancement
**Objective:** Integrate module manager with NCC validation

**Files to Modify:**
- `nixos/core/management/module-manager/handlers/module-manager.nix`

**Changes:**
- Use NCC validation APIs for dependency checking
- Report validation results through NCC formatting

### Phase 3: GENERISCHES Permission-System (2-3 Tage)

#### 3.1 GENERISCHE NCC Permission-APIs Erweitern
**Ziel:** Rollenbasierte Zugriffs-Kontrolle zu NCC als generische CLI-Infrastruktur hinzufügen

**GENERISCHE Dateien erstellen/modifizieren:**
```bash
# ALLES GENERISCH - baseNameOf ./. Pattern!
core/management/nixos-control-center/
├── submodules/
│   └── cli-permissions/      # GENERISCH: Rollen-Management
│       ├── default.nix       # GENERISCH: moduleName = baseNameOf ./.
│       ├── api.nix           # GENERISCHE API-Definition
│       ├── options.nix       # GENERISCH: getCurrentModuleMetadata
│       ├── config.nix        # GENERISCH: moduleName Parameter
│       ├── roles.nix         # Permission-Rollen
│       ├── policies.nix      # Permission-Policies
│       ├── access-control.nix # Zugriffs-Kontrolle
│       └── user-context.nix  # User-Erkennung
```

**Permission Architecture:**
```nix
# submodules/permissions/roles.nix
{
  # Standard roles (extend existing user roles)
  roles = {
    admin = {
      description = "Full system access";
      permissions = [ "system.*" "module.*" "security.*" ];
      inherits = [];
    };

    virtualization = {
      description = "Virtualization and container management";
      permissions = [ "infrastructure.homelab.*" "infrastructure.vm.*" ];
      inherits = [];
    };

    user = {
      description = "Basic user access";
      permissions = [ "system.status" "module.list" ];
      inherits = [];
    };
  };
}
```

#### 3.2 Update CLI Registry with Permissions
**Objective:** Add permission metadata to command registration

**Files to Modify:**
- `core/management/nixos-control-center/submodules/cli-registry/commands.nix`

**Enhanced Command Structure:**
```nix
# NEW: Commands with permission metadata
commands = [
  {
    name = "homelab-status";
    script = "${homelabStatus}/bin/nixos-control-center-homelab-status";
    description = "Show homelab status";
    category = "infrastructure";
    permissions = {
      roles = [ "admin" "virtualization" ];  # Required roles
      users = [];                           # Specific users (optional)
      groups = [];                          # Group membership (optional)
    };
  }
];
```

#### 3.3 Create Permission-Aware Command Filter
**Objective:** Filter commands based on user permissions

**Files to Create:**
- `core/management/nixos-control-center/submodules/cli-registry/filter.nix`

**Implementation:**
```nix
# filter.nix - Permission-aware command filtering
{ config, lib, ... }:
let
  cfg = config.${getModuleApi "cli-registry"};
  permissions = config.${getModuleApi "cli-permissions"};

  # Get current user context
  currentUser = permissions.user-context.currentUser;

  # Check if user has permission for command
  hasPermission = command: user:
    let
      cmdPerms = command.permissions or {};
      userRoles = permissions.getUserRoles user;
      userGroups = permissions.getUserGroups user;
    in
      # Allow if no permissions defined (backward compatibility)
      if cmdPerms == {} then true
      else
        # Check roles
        (cmdPerms.roles or [] == []) ||
        (lib.any (role: builtins.elem role userRoles) cmdPerms.roles) ||
        # Check specific users
        (builtins.elem user (cmdPerms.users or [])) ||
        # Check groups
        (lib.any (group: builtins.elem group userGroups) (cmdPerms.groups or []));

  # Filter commands based on permissions
  filterCommands = commands: user:
    builtins.filter (cmd: hasPermission cmd user) commands;

in {
  # Public API
  inherit hasPermission filterCommands;
}
```

#### 3.4 Update NCC API with Permissions
**Objective:** Expose permission functionality through NCC API

**Files to Modify:**
- `core/management/nixos-control-center/api.nix`

**Enhanced NCC API:**
```nix
core.management.nixos-control-center.api = {
  inherit formatter registry;

  # NEW: Permission APIs
  permissions = {
    checkAccess = user: command: config.${getModuleApi "cli-permissions"}.access-control.checkAccess user command;
    filterCommands = user: commands: config.${getModuleApi "cli-permissions"}.cli-filter.filterCommands commands user;
    getUserRoles = username: config.${getModuleApi "cli-permissions"}.user-context.getUserRoles username;
    getUserGroups = username: config.${getModuleApi "cli-permissions"}.user-context.getUserGroups username;
  };

  # Validation APIs
  validation = {
    validateModule = moduleName: { /* validation logic */ };
    validateSystem = { /* system checks */ };
    checkDependencies = moduleList: { /* dependency resolution */ };
    reportIssues = issues: { /* NCC-formatted error reporting */ };
  };
};
```

#### 3.5 Update NCC Commands with Permission Filtering
**Objective:** Make NCC CLI commands respect permissions

**Files to Modify:**
- `core/management/nixos-control-center/commands.nix`

**Implementation:**
```nix
# commands.nix - Permission-aware command help
{ config, lib, pkgs, ... }:
let
  cfg = config.${getModuleApi "nixos-control-center"};
  permissions = config.${getModuleApi "cli-permissions"};
  registry = config.${getModuleApi "cli-registry"};

  # Get current user (from environment or detection)
  currentUser = permissions.user-context.currentUser;

  # Filter available commands for current user
  availableCommands = permissions.cli-filter.filterCommands registry.commands currentUser;

  # Permission-aware help command
  nccHelp = pkgs.writeShellScriptBin "ncc" ''
    #!${pkgs.bash}/bin/bash
    echo "NixOS Control Center (NCC) - Available Commands:"
    echo "User: $(whoami) | Roles: ${permissions.getUserRoles currentUser}"
    echo ""

    ${lib.concatStringsSep "\n" (map (cmd: ''
      echo "${cmd.name} - ${cmd.description}"
    '') availableCommands)}

    echo ""
    echo "Use 'ncc <command> --help' for detailed help"
  '';

in {
  # Register permission-filtered NCC command
  environment.systemPackages = [ nccHelp ];
}
```

### Phase 4: Validated Module Discovery (2-3 days)

#### 4.1 Create Discovery Validation Library

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
- [ ] Permission system filters commands by user roles
- [ ] CLI shows only accessible commands per user
- [ ] Module discovery validates module structure
- [ ] Validation coordinator prevents invalid configurations
- [ ] System and Module managers coordinate properly
- [ ] CLI commands work with new architecture

### Quality Requirements
- [ ] All existing functionality preserved
- [ ] Permission system is backward compatible
- [ ] No breaking changes without migration path
- [ ] Comprehensive test coverage
- [ ] Updated documentation
- [ ] Clear permission error messages

### Performance Requirements
- [ ] Module discovery time < 2 seconds
- [ ] Permission checking < 100ms per command
- [ ] Validation overhead < 10% of build time
- [ ] CLI responsiveness maintained

## Timeline and Milestones

| Phase | Duration | Milestone |
|-------|----------|-----------|
| Phase 1: NCC Foundation | 2-3 days | NCC module created and integrated |
| Phase 2: Formatting Migration | 1-2 days | All modules use NCC formatting |
| Phase 3: Permission System | 2-3 days | Role-based command access control |
| Phase 4: Validated Discovery | 2-3 days | Module validation during discovery |
| Phase 5: Validation Pipeline | 2-3 days | Centralized validation coordination |

**Total Timeline:** 13-19 days

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
