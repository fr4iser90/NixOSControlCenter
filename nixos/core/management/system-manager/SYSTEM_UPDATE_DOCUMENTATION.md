# System Update Documentation

## Overview

The System Update functionality manages the deployment and update process of the NixOS Control Center configuration. It copies files from the Git repository to `/etc/nixos/`, preserving user configurations, and rebuilds the system.

## Architecture

### Source and Target Locations

1. **Source Location** (Repository):
   - **Remote**: `https://github.com/fr4iser90/NixOSControlCenter.git` (cloned to `/tmp/nixos-update/nixos`)
   - **Local**: `/home/<username>/Documents/Git/NixOSControlCenter/nixos`
   - **Contains**: All module code, default configs, flake.nix

2. **Target Location** (Deployed System):
   - `/etc/nixos/` - The actual NixOS configuration directory
   - **Contains**: Deployed modules, user configs, system-specific files

### Key Component

#### `system-update.nix` Handler
- **Location**: `nixos/core/system-manager/handlers/system-update.nix`
- **Purpose**: Main handler for system updates
- **Function**: 
  - Allows selection of update source (remote repo or local directory)
  - Copies files from source to `/etc/nixos/` DIRECTLY (no intermediate temp directory)
  - Preserves user configurations
  - Optionally rebuilds system

## How It Works

### Step-by-Step Process

1. **User runs**: `sudo ncc system-update`

2. **Source Selection**:
   - **Option 1**: Remote Repository (clones from GitHub to `/tmp/nixos-update/`)
   - **Option 2**: Local Directory (uses `/home/<username>/Documents/Git/NixOSControlCenter/nixos`)
   - **Option 3**: Update Channels (updates flake inputs only, exits after)

3. **Backup Creation**:
   - Creates backup in `/var/backup/nixos/<timestamp>/`
   - Keeps last 5 backups, removes older ones
   - Backs up entire `/etc/nixos/` directory

4. **File Copying Process**:
   
   **CRITICAL**: `configs/` is NOT in `COPY_ITEMS` and is NOT processed during update!
   
   **`configs/` directory** (NOT in COPY_ITEMS, NOT copied):
   - **NOT in COPY_ITEMS list** (line 481-493)
   - **NOT processed** in the copy loop (line 527-593)
   - **NOT copied** even if missing in target
   - Only safety check at end (line 597-599) ensures it's not accidentally overwritten
   - Symlinks in `configs/` are created by module activation scripts (AFTER build), not by system-update
   
   **`custom/` directory** (in COPY_ITEMS):
   - **NEVER overwritten** if exists in target
   - Only copied if doesn't exist in target
   - User custom modules are preserved
   
   **`core/` and `features/` directories** (in COPY_ITEMS):
   - Module-by-module update (NEVER `rm -rf` entire directory)
   - For each module individually:
     - Preserves config files (NEVER overwritten)
     - Updates module code (everything except config files)
     - Handles version migrations if needed
     - Config files are now directly in module directories
   
   **Other directories** (`packages/`, `desktop/`, etc.):
   - Completely overwritten (`rm -rf` then copy)
   
   **Legacy directories** (`modules/`, `lib/`, `packages/`):
   - **DELETED** before copying (line 522: `sudo rm -rf "$NIXOS_DIR/modules" "$NIXOS_DIR/lib" "$NIXOS_DIR/packages"`)
   - These are legacy and removed
   
   **`flake.nix`** (in COPY_ITEMS):
   - Always overwritten with repository version
   
   **Protected files** (NOT in COPY_ITEMS, never touched):
   - `hardware-configuration.nix` - NEVER overwritten
   - `flake.lock` - NEVER overwritten

5. **Build Process** (if not auto-build):
   - Prompts user: "Do you want to build and switch? (y/n)"
   - If yes: Runs `nixos-rebuild switch --flake /etc/nixos#<hostname>` or `ncc build switch`
   - If no: Exits, user can build manually

### File Preservation Strategy

**ALWAYS Preserved** (never overwritten):
- `hardware-configuration.nix` - System-specific hardware config
- `flake.lock` - Generated lock file
- `configs/` directory - User-editable configs (protected by safety check, but NOT copied)
- `custom/` directory - User custom modules (if exists in target)
- Config files in modules - User configs within modules (NEVER touched)

**ALWAYS Overwritten**:
- `flake.nix` - Updated with repository version
- Module code files (everything except config files)
- Other directories (`packages/`, `desktop/`, etc.)

**Conditionally Copied**:
- `custom/` - Only copied if doesn't exist in target (in COPY_ITEMS)

**NOT Processed** (not in COPY_ITEMS):
- `configs/` - NOT copied, NOT processed, only protected from accidental overwrite

**Always Deleted** (legacy directories):
- `modules/` - Removed before update (legacy)
- `lib/` - Removed before update (legacy)  
- `packages/` - Removed before update (legacy, but new `packages/` may be copied if in source)

## Configuration Loading During Build

### Critical: Build-Time Config Loading

**When `nixos-rebuild switch` runs**:
1. Changes working directory to `/etc/nixos/`
2. Evaluates `flake.nix` from `/etc/nixos/`
3. `flake.nix` calls: `configLoader.loadSystemConfig ./. ./system-config.nix`
   - `./` = `/etc/nixos/` (current working directory during build)
4. Config loader searches in this order (ONLY deployed files in `/etc/nixos/`, NEVER repository files):
   - **First**: `/etc/nixos/configs/module-manager-config.nix` (central config - HIGHEST PRIORITY)
    - This is a symlink pointing to the actual file in module directory
    - User edits this file for easy access to all configs in one place
   - **Second**: `/etc/nixos/core/module-management/module-manager/module-manager-config.nix` (module config - FALLBACK)
     - Actual file location (target of symlink)
     - Used if central symlink doesn't exist or is broken
   - **If nothing found**: Returns `{}` (empty attribute set)
     - Module will use its default values
     - **Repository files are NEVER loaded, not even as fallback!**

**CRITICAL**: The config loader uses **ONLY deployed files in `/etc/nixos/`**. Repository files are **NEVER** loaded, not even as fallback!

### After Build (Activation Scripts)

- **Symlinks are created**: `/etc/nixos/configs/<config-name>.nix` → `/etc/nixos/core/<module>/<config-name>.nix`
- **When**: During system activation (AFTER build, via `config.system.activationScripts`)
- **Who**: Each module creates its own symlink via `configHelpers.setupConfigFile`
- **Purpose**: Central location for ALL user-editable configs
- **Why**: End users can quickly find and edit ALL configurable options in ONE place (`/etc/nixos/configs/`)
- User edits files in `/etc/nixos/configs/` (central location)
- Changes are written to actual files in module directories (via symlink)
- **Available configs in `/etc/nixos/configs/`**:
  - `desktop-config.nix` - Desktop environment settings
  - `audio-config.nix` - Audio configuration
  - `localization-config.nix` - Locale, keyboard, timezone
  - `hardware-config.nix` - CPU, GPU, RAM settings
  - `module-manager-config.nix` - Enable/disable features (system-logger, ssh-client-manager, etc.)
  - `packages-config.nix` - Package management
  - `network-config.nix` - Network settings
  - `security-config.nix` - Security settings
  - And more... (see `optionalConfigs` list in config-loader.nix, lines 87-114)

## Module Update Process

### For `core/` and `features/` Modules

1. **For each module** in source:
   - Check if module has `options.nix` (versioned module)
   - **If versioned**:
     - Compare versions (source vs target)
     - If versions differ: Run migration (if implemented)
     - Update module code (everything except config files)
     - Config files remain untouched
   - **If not versioned**:
     - Check if target module exists
     - If exists: Run Stage 0 → 1 migration (extract config from `system-config.nix`)
     - If not: Copy completely

2. **Config File Protection**:
   - Config files are **NEVER overwritten**
   - Only module code is updated
   - User configs remain untouched

## Important Notes

1. **Always run from `/etc/nixos/`**: System update must be executed from deployed location

2. **Config Preservation**: 
   - `/etc/nixos/configs/` is **NEVER overwritten** (protected by safety check)
   - `/etc/nixos/configs/` is **NOT copied** during update (not in COPY_ITEMS)
   - User configs in modules are **NEVER overwritten**
   - Only module code is updated

3. **Build Location**: 
   - When `nixos-rebuild` runs, it evaluates from `/etc/nixos/`
   - Config loader searches in `/etc/nixos/configs/` **FIRST**
   - Then searches in `/etc/nixos/core/<module>/` and `/etc/nixos/features/<module>/`
   - **Repository files are NEVER loaded, not even as fallback**

4. **Repository Files**: 
   - Repository config files are **DEFAULT templates**
   - They are copied during initial deployment to `/etc/nixos/`
   - After deployment, **ONLY** deployed files in `/etc/nixos/` are used
   - Repository files are **NEVER** accessed during build

5. **Symlink Creation**:
   - Symlinks in `/etc/nixos/configs/` are created by module activation scripts
   - Each module creates its own symlink via `configHelpers.setupConfigFile`
   - Symlinks are created AFTER build, during system activation
   - System-update does NOT create or manage symlinks
