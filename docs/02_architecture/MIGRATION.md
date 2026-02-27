# NCC CLI Migration Plan

Complete implementation plan to migrate from flat to hierarchical command structure.

---

## Goal

Transform NCC from 39 flat commands to 6 clean domains.

**No aliases. No compromises. Clean break.**

---

## Current State → Target State

### Before
```
ncc (39 flat commands)
```

### After
```
ncc (6 domains)
├── system
├── modules
├── desktop
├── vm
├── chronicle
└── nixify
```

---

## Phase 1: Registry Enhancement

### 1.1 Extend types.nix

**File:** `nixos/core/management/cli-registry/lib/types.nix`

**Add:**
```nix
domain = lib.mkOption {
  type = lib.types.str;
  description = "Domain this command belongs to";
  example = "system";
};

parent = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
  description = "Parent command for subcommands";
  example = "vm";
};

internal = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = "Hide from public help";
};
```

### 1.2 Update API

**File:** `nixos/core/management/cli-registry/api.nix`

**Add:**
```nix
# Get commands by domain
getCommandsByDomain = config: domain:
  let
    allCommands = getRegisteredCommands config;
  in
    lib.filter (cmd: cmd.domain or null == domain) allCommands;

# Get all domains
getDomains = config:
  let
    allCommands = getRegisteredCommands config;
    domains = lib.unique (map (cmd: cmd.domain) allCommands);
  in
    lib.sort (a: b: a < b) domains;

# Get subcommands
getSubcommands = config: parentName:
  let
    allCommands = getRegisteredCommands config;
  in
    lib.filter (cmd: cmd.parent or null == parentName) allCommands;
```

---

## Phase 2: Main Script Update

### 2.1 Command Resolution

**File:** `nixos/core/management/cli-registry/scripts/main-script.nix`

**Logic:**
```
1. No args → Show domains
2. Domain only → Show TUI or domain commands
3. Domain + action → Execute command
4. Domain + action + subaction → Execute nested command
```

**Example:**
```bash
ncc                    → Show all domains
ncc system             → Show system TUI or commands
ncc system build       → Execute build
ncc vm test arch run   → Execute VM test command
```

---

## Phase 3: Module Migration

### 3.1 System Manager

**File:** `nixos/core/management/system-manager/commands.nix`

**Before:**
```nix
{ name = "build"; ... }
{ name = "system-update"; ... }
{ name = "update-channels"; ... }
```

**After:**
```nix
{
  name = "system";
  domain = "system";
  type = "manager";
  script = "${systemTui}/bin/ncc-system-tui";
}
{
  name = "build";
  domain = "system";
  parent = "system";
  script = "${buildScript}/bin/ncc-system-build";
}
{
  name = "update";
  domain = "system";
  parent = "system";
  script = "${updateScript}/bin/ncc-system-update";
}
{
  name = "update-channels";
  domain = "system";
  parent = "system";
  script = "${channelsScript}/bin/ncc-system-update-channels";
}
```

**Commands to migrate:**
- `build` → `system build`
- `system-update` → `system update`
- `update-channels` → `system update-channels`
- `log-system-report` → `system report`
- `check-module-versions` → `system check-versions`
- `update-modules` → `system update-modules`
- `migrate-system-config` → `system migrate-config`
- `validate-system-config` → `system validate-config`

---

### 3.2 Module Manager

**File:** `nixos/core/management/module-manager/commands.nix`

**Before:**
```nix
{ name = "module-manager"; ... }
```

**After:**
```nix
{
  name = "modules";
  domain = "modules";
  type = "manager";
  script = "${modulesTui}/bin/ncc-modules-tui";
}
{
  name = "enable";
  domain = "modules";
  parent = "modules";
  script = "${enableScript}/bin/ncc-modules-enable";
}
{
  name = "disable";
  domain = "modules";
  parent = "modules";
  script = "${disableScript}/bin/ncc-modules-disable";
}
```

**Commands to migrate:**
- `module-manager` → `modules` (TUI)

---

### 3.3 Desktop Manager

**File:** `nixos/core/base/desktop/commands.nix`

**Before:**
```nix
{ name = "desktop-manager"; ... }
```

**After:**
```nix
{
  name = "desktop";
  domain = "desktop";
  type = "manager";
  script = "${desktopTui}/bin/ncc-desktop-tui";
}
{
  name = "enable";
  domain = "desktop";
  parent = "desktop";
  script = "${enableScript}/bin/ncc-desktop-enable";
}
{
  name = "disable";
  domain = "desktop";
  parent = "desktop";
  script = "${disableScript}/bin/ncc-desktop-disable";
}
```

**Commands to migrate:**
- `desktop-manager` → `desktop` (TUI)

---

### 3.4 VM Manager

**File:** `nixos/modules/infrastructure/vm/commands.nix`

**Before:**
```nix
{ name = "vm"; ... }
{ name = "vm-status"; ... }
{ name = "vm-list"; ... }
{ name = "test-arch-run"; ... }
{ name = "test-arch-reset"; ... }
# ... +14 more test commands
```

**After:**
```nix
{
  name = "vm";
  domain = "vm";
  type = "manager";
  script = "${vmTui}/bin/ncc-vm-tui";
}
{
  name = "status";
  domain = "vm";
  parent = "vm";
  script = "${statusScript}/bin/ncc-vm-status";
}
{
  name = "list";
  domain = "vm";
  parent = "vm";
  script = "${listScript}/bin/ncc-vm-list";
}

# For each distro (arch, fedora, kali, mint, nixos, pop, ubuntu, zorin):
{
  name = "test-<distro>-run";
  domain = "vm";
  parent = "vm";
  script = "${runScript}/bin/ncc-vm-test-<distro>-run";
}
{
  name = "test-<distro>-reset";
  domain = "vm";
  parent = "vm";
  script = "${resetScript}/bin/ncc-vm-test-<distro>-reset";
}
```

**Commands to migrate (22 total):**
- `vm` → `vm` (keep as TUI)
- `vm-status` → `vm status`
- `vm-list` → `vm list`
- `test-arch-run` → `vm test-arch-run`
- `test-arch-reset` → `vm test-arch-reset`
- ... +14 more test commands

**Impact:** 22 flat → 1 domain + subcommands

---

### 3.5 Chronicle (Already Correct!)

**File:** `nixos/modules/specialized/chronicle/commands.nix`

**Current:**
```nix
{
  name = "chronicle";
  domain = "chronicle";  # Add domain field
  type = "manager";
  script = "${chronicleTui}/bin/ncc-chronicle-tui";
}
{
  name = "start";
  domain = "chronicle";  # Add domain field
  parent = "chronicle";  # Add parent field
  script = "${startScript}/bin/ncc-chronicle-start";
}
```

**Status:** ✅ Already hierarchical, just add domain/parent fields!

---

### 3.6 Nixify (Already Correct!)

**File:** `nixos/modules/specialized/nixify/commands.nix`

**Current:**
```nix
{
  name = "nixify";
  domain = "nixify";  # Add domain field
  type = "manager";
  script = "${nixifyTui}/bin/ncc-nixify-tui";
}
{
  name = "extract";
  domain = "nixify";  # Add domain field
  parent = "nixify";  # Add parent field
  script = "${extractScript}/bin/ncc-nixify-extract";
}
```

**Status:** ✅ Already hierarchical, just add domain/parent fields!

---

## Phase 4: TUI Creation

Create TUI for each domain that doesn't have one:

### 4.1 System TUI

**File:** `nixos/core/management/system-manager/tui/menu.nix`

**Menu Items:**
- Build Configuration
- Update System
- Update Channels
- Rollback
- System Report
- Check Versions
- Update Modules
- Migrate Config
- Validate Config

---

### 4.2 Desktop TUI

**File:** `nixos/core/base/desktop/tui/menu.nix`

**Menu Items:**
- Enable Desktop
- Disable Desktop
- List Desktops
- Show Status

---

### 4.3 VM TUI

**File:** `nixos/modules/infrastructure/vm/tui/menu.nix`

**Menu Items:**
- Show Status
- List Distros
- Test VM submenu (arch, fedora, kali, etc.)
  - Run
  - Reset

---

## Phase 5: Script Updates

### 5.1 Main NCC Script

**File:** `nixos/core/management/cli-registry/scripts/main-script.nix`

**Update command resolution:**
1. Parse args: `ncc <domain> <action> [subaction] [args]`
2. If no domain → Show domain list
3. If domain only → Show domain TUI or help
4. If domain + action → Execute command
5. If domain + action + subaction → Execute nested command

---

### 5.2 Help System

Update help to show:
```bash
ncc help              → List all domains
ncc system help       → List system commands
ncc vm help           → List VM commands
```

---

## Phase 6: Remove Old Commands

Delete all flat command registrations. No aliases.

**Files to update:**
- `system-manager/commands.nix` - Remove flat commands
- `module-manager/commands.nix` - Remove flat commands
- `desktop/commands.nix` - Remove flat commands
- `vm/commands.nix` - Remove flat commands

---

## Implementation Checklist

### Registry
- [ ] Add `domain` field to types.nix
- [ ] Add `parent` field to types.nix
- [ ] Add `internal` field to types.nix
- [ ] Update API with domain functions
- [ ] Update main script for hierarchical resolution

### Modules
- [ ] Migrate system-manager commands
- [ ] Migrate module-manager commands
- [ ] Migrate desktop-manager commands
- [ ] Migrate VM commands (22 commands!)
- [ ] Update chronicle with domain field
- [ ] Update nixify with domain field

### TUIs
- [ ] Create system TUI
- [ ] Create desktop TUI
- [ ] Update VM TUI
- [ ] Keep chronicle TUI (already good)
- [ ] Keep nixify TUI (already good)
- [ ] Keep modules TUI (already good)

### Cleanup
- [ ] Remove all flat command registrations
- [ ] Update documentation
- [ ] Test all commands
- [ ] Update shell completions (if any)

---

## Testing Strategy

### Test Matrix

| Domain | TUI | CLI Commands | Subcommands |
|--------|-----|--------------|-------------|
| system | `ncc system` | `build`, `update`, etc. | - |
| modules | `ncc modules` | `enable`, `disable` | - |
| desktop | `ncc desktop` | `enable`, `disable` | - |
| vm | `ncc vm` | `status`, `list` | `test-*-run/reset` |
| chronicle | `ncc chronicle` | `start`, `stop`, etc. | - |
| nixify | `ncc nixify` | `extract`, `iso` | `build`, `test` |

### Test Commands

```bash
# Root
ncc                              # Should show 6 domains

# System Domain
ncc system                       # Should show TUI
ncc system build                 # Should build
ncc system update                # Should update

# VM Domain
ncc vm                           # Should show TUI
ncc vm status                    # Should show status
ncc vm test-arch-run             # Should start arch VM

# Chronicle Domain
ncc chronicle                    # Should show TUI
ncc chronicle start              # Should start recording
```

---

## Rollout Plan

### Stage 1: Registry (Week 1)
- Extend types
- Update API
- Update main script

### Stage 2: Core Domains (Week 2)
- Migrate system
- Migrate modules
- Migrate desktop

### Stage 3: Infrastructure (Week 3)
- Migrate VM (biggest impact!)
- Create/update TUIs

### Stage 4: Specialized (Week 4)
- Update chronicle
- Update nixify

### Stage 5: Cleanup (Week 5)
- Remove flat commands
- Final testing
- Documentation

---

## Success Criteria

✅ `ncc` shows exactly 6 domains
✅ All commands follow `ncc <domain> <action>` pattern
✅ No flat commands remain
✅ Every domain has TUI
✅ All tests pass
✅ Documentation updated

---

## Breaking Changes

**This is a breaking change!**

Old commands will not work:
- ❌ `ncc build`
- ❌ `ncc system-update`
- ❌ `ncc test-arch-run`

New commands required:
- ✅ `ncc system build`
- ✅ `ncc system update`
- ✅ `ncc vm test-arch-run`

**No compatibility layer. Clean break.**

---

## The Way Forward

1. Document pattern ✅ (Done!)
2. Extend registry (Week 1)
3. Migrate modules (Week 2-4)
4. Remove old commands (Week 5)
5. Ship it! 🚀

Clean. Hierarchical. Professional.

This is the way.
