# Konkreter Implementierungsplan: Feature Version Checker & Smart Updates

## 🎯 Decisions

### 1. Version-Registry: Wo?

**Decision**: Auto-Discovery from `options.nix` - NO version in `metadata.nix`

**Why**:
- ✅ Versions come automatically from `features/*/options.nix`
- ✅ No manual registry needed
- ✅ Single source of truth: `options.nix`
- ✅ No redundancy

**Structure**:
```nix
# features/metadata.nix
{
  features = {
    "system-discovery" = {
      # NO version here! Version comes only from options.nix
      dependencies = [];
      conflicts = [];
    };
    # ... all features
  };
}
```

**Why no version in `metadata.nix`?**
- ✅ **Versions in `options.nix`**: `featureVersion` (code version) and `stableVersion` (optional, stable)
- ✅ **User's current version**: `config.features.*._version` (from user config)
- ✅ **Available versions**: Read automatically from `options.nix` (Auto-Discovery)
- ✅ **User can choose**: Code version (`featureVersion`) or Stable (`stableVersion`)
- ✅ **No redundancy**: Versions are only defined in `options.nix`

**Version Definitions:**
- **`featureVersion`** = Version in code (what's in Git, not necessarily "latest")
- **`stableVersion`** = Stable, tested version (optional, if not set = `featureVersion`)
- **User's `_version`** = What user currently has installed
- **Available versions** = What's available in code (`featureVersion` and optionally `stableVersion`)

**Naming Conventions:**

| **Term** | **Our System** | **Source** | **Description** |
|----------|-----------------|------------|-----------------|
| **`installed`** / **`current`** | `config.features.*._version` | User config | What's currently installed on the system |
| **`available`** / **`latest`** | `featureVersion` / `latestVersion` | `options.nix` | Latest version available in Git/repository |
| **`stable`** | `stableVersion` | `options.nix` | Tested, stable version (optional) |

**Version Checker Output:**
```
Feature              Installed  Available  Stable    Status
system-discovery     1.0        2.0        1.5       ⚠️  Update available
```

**Column Definitions:**
- **Installed** = User's current version (from `config.features.*._version`)
- **Available** = Latest version in Git (from `featureVersion`/`latestVersion` in `options.nix`)
- **Stable** = Stable version (from `stableVersion` in `options.nix`, or `latestVersion` if not set)

**Mapping to Code:**
- `installed` / `current` → `config.features.*._version` (User's version)
- `available` / `latest` → `featureVersion` / `latestVersion` in `options.nix` (Git version)
- `stable` → `stableVersion` in `options.nix` (tested, optional)

### 2. Command Center: Zentrales Feature-Management?

**Decision**: NO - Features manage themselves

**Why**:
- ✅ Jedes Feature hat eigene `commands.nix`
- ✅ Features are independent
- ✅ Command Center ist nur Router (ncc <command>)
- ✅ No central logic needed

**What Command Center does**:
- Routes commands: `ncc check-feature-versions` → `system-updater/scripts/check-versions.nix`
- Shows command list
- **NOT**: Edit feature configs, initialize, etc.

**What Features do**:
- Register own commands
- Initialize own configs (if needed)
- Own migrations

### 3. Config-Initialisierung: Wer?

**Decision**: Features initialize their own configs

**Why**:
- ✅ Features know what they need
- ✅ No central logic needed
- ✅ Features are independent

**Pattern**:
```nix
# In feature/default.nix
config = mkIf cfg.enable {
      # Feature initializes own configs if needed
      system.activationScripts.feature-init = {
        text = ''
          # Initialize configs/feature-config.nix if not present
        '';
      };
}
```

---

## 📋 Phase 2: Version Checker - Concrete Plan

### Step 2.1: Implement Auto-Discovery (1 hour) ⭐ NEW!

**File**: `features/default.nix` and `features/metadata.nix`

**What**:
- Automatically read features from `features/` directory
- Automatically read `featureVersion` from `features/*/options.nix`
- Automatically generate `metadata.nix` (instead of manual entry)

**Implementation**:
```nix
# features/default.nix
# Automatically read all features from directory
allFeatureDirs = builtins.readDir ./.;
featureModuleMap = lib.mapAttrs' (name: type:
  lib.nameValuePair name (./. + "/${name}")
) (lib.filterAttrs (name: type: 
  type == "directory" && name != ".TEMPLATE"
) allFeatureDirs);

# Automatically read versions from options.nix
# TWO VERSIONS: latestVersion (latest) and stableVersion (stable, optional)
getAvailableVersions = featureName:
  let
    optionsFile = ./${featureName}/options.nix;
    # Read versions directly from options.nix
    options = import optionsFile { inherit lib; };
    latestVersion = options.latestVersion or "1.0";  # Latest version (bleeding edge, what's in Git)
    stableVersion = options.stableVersion or latestVersion;  # Stable version (tested, optional)
  in {
    latest = latestVersion;  # Latest version (bleeding edge)
    stable = stableVersion;  # Stable version (tested, optional)
  };
```

**IMPORTANT:**
- ✅ **`latestVersion` in `options.nix`** = Latest version (bleeding edge, what's in Git)
- ✅ **`stableVersion` in `options.nix`** = Stable version (tested, optional, defaults to `latestVersion`)
- ✅ **Read automatically** (Auto-Discovery)
- ✅ **User can choose**: Latest (`latestVersion`) or Stable (`stableVersion`) or pin to specific version
- ❌ **NO version in `metadata.nix`** - only dependencies/conflicts!

**Where versions are defined:**
- **Latest version**: `latestVersion` in `features/${name}/options.nix` (bleeding edge, what's in Git)
- **Stable version**: `stableVersion` in `features/${name}/options.nix` (optional, defaults to `latestVersion`)
- **User's current version**: `config.features.${name}._version` (from user config)
- **Available versions**: Read automatically from `options.nix` (Auto-Discovery)

**NO fallback needed!**

**Auto-Discovery automatically reads from `options.nix`:**
- ✅ `featureVersion` in `options.nix` = the ONLY version
- ✅ Automatically read, no manual entry needed

**Version Checker Logic**:
```nix
# system-updater/feature-version-check.nix
let
  # Auto-Discovery: Get versions automatically from options.nix
  # TWO VERSIONS: latestVersion (latest) and stableVersion (stable, optional)
  getAvailableVersions = featureName:
    let
      optionsFile = ../../features/${featureName}/options.nix;
      # Read versions directly from options.nix
      options = import optionsFile { inherit lib; };
      latestVersion = options.latestVersion or "1.0";  # Latest version (bleeding edge, what's in Git)
      stableVersion = options.stableVersion or latestVersion;  # Stable version (tested, optional)
    in {
      latest = latestVersion;  # Latest version (bleeding edge)
      stable = stableVersion;  # Stable version (tested, optional)
    };
  
  # Auto-Discovery: Find available migrations through directory scan
  getAvailableMigrations = featureName:
    let
      migrationsDir = ../../features/${featureName}/migrations;
      # Scan migrations directory for all vX-to-vY.nix files
      allFiles = tryEval (builtins.readDir migrationsDir);
    in if allFiles.success then
      lib.mapAttrsToList (name: _: 
        # Parse "v1.0-to-v2.0.nix" → { from = "1.0"; to = "2.0"; }
        let
          parts = lib.splitString "-to-v" (lib.removeSuffix ".nix" name);
          from = lib.removePrefix "v" (lib.elemAt parts 0);
          to = lib.elemAt parts 1;
        in { inherit from to; path = migrationsDir + "/${name}"; }
      ) (lib.filterAttrs (name: _: lib.hasSuffix ".nix" name) allFiles.value)
    else [];
  
  # Collect INSTALLED versions from config (User System)
  # "installed" = what's on the system
  installedVersions = lib.mapAttrs (name: cfg: 
    cfg._version or "unknown"
  ) config.features;
  
  # Get AVAILABLE versions (automatically from options.nix)
  # "available" = what's in Git/repository
  availableVersions = lib.mapAttrs (name: _: 
    getAvailableVersions name
  ) config.features;
  
  # Get AVAILABLE migrations (automatically through directory scan)
  availableMigrations = lib.mapAttrs (name: _:
    getAvailableMigrations name
  ) config.features;
  
  # Combine for comparison
  featureVersions = lib.mapAttrs (name: installed: {
    installed = installed;  # User's installed version (from config.features.*._version)
    available = availableVersions.${name}.latest or "unknown";  # Available version in Git (bleeding edge)
    stable = availableVersions.${name}.stable or "unknown";  # Stable version (tested, optional)
    migrations = availableMigrations.${name} or [];  # From migrations/ directory
  }) installedVersions;
in {
  # ...
}
```

**IMPORTANT: There are TWO versions (optional)!**
- ✅ **`latestVersion` in `options.nix`** = Latest version (bleeding edge, what's in Git)
- ✅ **`stableVersion` in `options.nix`** = Stable version (tested, optional, defaults to `latestVersion`)
- ✅ **Read automatically** (Auto-Discovery)
- ✅ **User can choose**: Latest (`latestVersion`) or Stable (`stableVersion`)
- ❌ **NO version in `metadata.nix`** - only dependencies/conflicts!

**Version Definitions (THREE versions):**
1. **User's Current Version** = What user currently has installed
   - Source: `config.features.*._version` (from user config)
   - Example: User has version 1.0 installed
   - User can keep this version (pinning)

2. **Latest Version** = Latest version in code (bleeding edge)
   - Source: `latestVersion` in `options.nix` (what's in Git)
   - Example: Code has version 2.0
   - User can update to this version

3. **Stable Version** = Stable, tested version (optional)
   - Source: `stableVersion` in `options.nix` (tested, optional, defaults to `latestVersion`)
   - Example: Stable version is 1.5
   - User can update to this version instead of latest

**How it works:**
- User's current version (1.0) vs. Available versions (latest: 2.0, stable: 1.5)
- User can choose: Stay on 1.0 (pin), update to 1.5 (stable), or update to 2.0 (latest)

### Step 2.2: Feature Version Collector (1 hour)

**File**: `system-updater/feature-version-check.nix`

**What**:
- Collect all feature versions from `config.features.*._version`
- Read `metadata.nix` for available versions
- Compare current vs. available versions

**Functions**:
```nix
# Collects: { "system-discovery" = { current = "1.0"; latest = "1.0"; }; }
getFeatureVersions = config: metadata -> attrs

# Prüft ob Update verfügbar
needsUpdate = currentVersion: availableVersion -> bool

# Compare versions
compareVersions = v1: v2 -> -1 | 0 | 1
```

### Step 2.3: Version Registry - Auto-Discovery (1 hour)

**Implementation**: Auto-Discovery from `options.nix`
- ✅ Versions are read automatically from `features/*/options.nix`
- ✅ No manual `metadata.nix` for versions needed
- ✅ `featureVersion` and `stableVersion` are read directly from each feature's `options.nix`
- ✅ No manual registry - everything automatic!

**How it works**:
- Current version: `config.features.*._version` (from User-Config)
- Available version: `featureVersion` / `latestVersion` from `options.nix` (Auto-Discovery)
- Stable version: `stableVersion` from `options.nix` (optional)
- No redundancy - single source of truth: `options.nix`

### Step 2.4: Command `ncc check-feature-versions` (1 hour)

**File**: `system-updater/scripts/check-versions.nix`

**What**:
- Script that uses version checker
- Shows table with all features
- Shows update status

**Output:**
```
Feature              Installed  Available  Stable    Status
system-discovery     1.0        2.0        1.5       ⚠️  Update available (available: 2.0, stable: 1.5)
ssh-client-manager   1.0        2.0        1.5       ⚠️  Update available (migration: yes)
vm-manager           1.5        2.0        1.5       ✅  Installed (stable)
```

**Column Definitions:**
- **Installed** = User's current version (from `config.features.*._version`)
- **Available** = Latest version in Git (from `featureVersion`/`latestVersion` in `options.nix`, bleeding edge)
- **Stable** = Stable version (from `stableVersion` in `options.nix`, or `latestVersion` if not set)

**Registration**: In `system-updater/commands.nix` (or `default.nix`)

---

## 📋 Phase 3: Smart Update Logic - Concrete Plan

### Step 3.1: Version Management & Migration Detection (1 hour)

**File**: `system-updater/feature-version-check.nix` (extend)

**How are versions managed?**

**1. Available Versions (in code):**
- ✅ Latest version: `latestVersion` in `options.nix` (bleeding edge, what's in Git)
- ✅ Stable version: `stableVersion` in `options.nix` (tested, optional, defaults to `latestVersion`)
- ✅ Read automatically: `import ./features/${name}/options.nix` → `latestVersion` and `stableVersion`
- ✅ No manual registry needed!

**2. User's Current Version:**
- ✅ From `config.features.*._version` (user config)
- ✅ Set during build (from `latestVersion` or user pinning)

**3. Available Migrations:**
- ✅ Found through directory scan: `features/${name}/migrations/`
- ✅ Reads all `vX-to-vY.nix` files
- ✅ Creates migration map: `{ "1.0-to-2.0" = migrationPlan; ... }`

**4. Find Migration Chain:**
```nix
# Find migration chain automatically through directory scan
findMigrationChain = featureName: fromVersion: toVersion:
  let
    migrationsDir = ../../features/${featureName}/migrations;
    allMigrations = builtins.readDir migrationsDir;
    migrationFiles = lib.filterAttrs (name: _: lib.hasSuffix ".nix" name) allMigrations;
    
    # Parse migration files: "v1.0-to-v2.0.nix" → { from = "1.0"; to = "2.0"; }
    parseMigrationName = name:
      let
        parts = lib.splitString "-to-v" (lib.removeSuffix ".nix" name);
        from = lib.removePrefix "v" (lib.elemAt parts 0);
        to = lib.elemAt parts 1;
      in { inherit from to; };
    
    # Find direct migration
    directMigration = lib.findFirst (m: m.from == fromVersion && m.to == toVersion) null
      (lib.mapAttrsToList (name: _: parseMigrationName name) migrationFiles);
    
    # If direct migration exists, return it
    # Otherwise, find chain (e.g., 1.0 → 1.1 → 2.0)
  in if directMigration != null then [fromVersion toVersion]
     else findMigrationChainRecursive fromVersion toVersion migrationFiles;
```

**What**:
- Checks if migration exists: `migrations/v${fromVersion}-to-v${toVersion}.nix`
- Supports chain migrations (upgrade AND downgrade)
- Supports both directions: upgrade (1.0 → 2.0) and downgrade (6.0 → 1.5)
- **Automatic detection** through directory scan (no manual registry!)

**Funktion**:
```nix
hasMigration = featureName: fromVersion: toVersion -> bool
findMigrationChain = featureName: fromVersion: toVersion -> [versions] | null

# Example chains:
# Upgrade: 1.0 → 2.0 → [1.0, 2.0] (if v1.0-to-v2.0.nix exists)
# Chain: 1.0 → 1.1 → 2.0 → [1.0, 1.1, 2.0] (if v1.0-to-v1.1.nix and v1.1-to-v2.0.nix exist)
# Downgrade: 6.0 → 1.5 → [6.0, 5.0, 4.0, 3.0, 2.0, 1.5] (if all migrations exist)
```

**Downgrade Logic:**
- If `toVersion < fromVersion` → downgrade
- Finds all migration steps backwards by scanning migrations directory
- Runs migrations in reverse sequence
- Warns user about potential data loss

### Step 3.2: Update Strategy Logic (1 hour)

**File**: `system-updater/feature-version-check.nix` (extend)

**What**:
- Determines update strategy for each feature
- `"unknown"` → unversioned
- `"current"` → already up to date
- `"auto"` → migration available
- `"manual"` → update available, but no migration

**Funktion**:
```nix
getUpdateStrategy = featureName -> "unknown" | "current" | "auto" | "manual"
```

### Step 3.3: Smart Update Command (2 hours)

**File**: `system-updater/scripts/smart-update.nix`

**What**:
- Command: `ncc update-features [--feature=name] [--dry-run] [--auto]`
- Shows update status
- Asks user (if not `--auto`)
- Updates features with `"auto"` strategy
- Warning for features with `"manual"` strategy

**Logic**:
1. Check all features
2. Show update status
3. Ask user (if not `--auto`)
4. Update features with `"auto"` strategy
5. Warning for features with `"manual"` strategy

### Step 3.4: Feature Migration Execution (1 hour)

**File**: `system-updater/handlers/feature-migration.nix` (new)

**What**:
- Executes feature migrations (upgrade AND downgrade)
- Loads migration plan from `migrations/vX-to-vY.nix`
- Supports both directions:
  - **Upgrade**: 1.0 → 2.0 (forward migration)
  - **Downgrade**: 6.0 → 1.5 (backward migration chain)
- Applies migration:
  - Option renamings
  - Type conversions
  - Structure mappings
- Updates `_version` in user config
- Creates backup

**Downgrade Handling:**
- Detects if `toVersion < fromVersion`
- Finds migration chain backwards
- Runs migrations in reverse sequence
- Shows warning: "Downgrading may lose data from newer versions"
- Asks user confirmation before downgrade

---

## 📁 File Structure

```
system-updater/
├── default.nix
├── options.nix
├── feature-version-check.nix      # NEW: Version Checker Logic
├── handlers/
│   └── feature-migration.nix       # NEW: Migration Execution
├── scripts/
│   ├── check-versions.nix          # NEW: ncc check-feature-versions
│   └── smart-update.nix            # NEW: ncc update-features
├── update.nix
├── feature-manager.nix
└── ...

features/
└── metadata.nix                    # ERWEITERN: Version-Info hinzufügen
```

---

## 🎯 Concrete Steps (in order)

### NOW (Phase 2):

1. **Implement Auto-Discovery** (1 hour) ⭐ NEW!
   - Automatically read features from `features/` directory
   - Automatically read `featureVersion` from `features/*/options.nix`
   - Automatically generate `metadata.nix` (instead of manual entry)
   - **Result**: New features are automatically recognized!

2. **Extend `metadata.nix`** (30 Min) - ONLY dependencies/conflicts
   - **NO version** in `metadata.nix`!
   - Only `dependencies` and `conflicts` (if needed)
   - Version comes automatically from `options.nix` (Auto-Discovery)

2. **Create `feature-version-check.nix`** (1 hour)
   - Collect versions from `config.features.*._version`
   - Read `metadata.nix`
   - Comparison logic

3. **Create `scripts/check-versions.nix`** (1 hour)
   - Command: `ncc check-feature-versions`
   - Show table
   - Register in `commands.nix` or `default.nix`

4. **Test** (30 Min)
   - `ncc check-feature-versions` should show all features

### THEN (Phase 3):

5. **Extend `feature-version-check.nix`** (1 hour)
   - Migration Detection
   - Update Strategy Logic

6. **Create `scripts/smart-update.nix`** (2 hours)
   - Command: `ncc update-features`
   - Smart Update Logic

7. **Create `handlers/feature-migration.nix`** (1 hour)
   - Migration Execution

8. **Test** (30 Min)
   - `ncc update-features --dry-run`

---

## ❓ Open Questions Answered

### Q: How are versions managed?
**A**: Automatically through Auto-Discovery:
- ✅ **Code Version**: `featureVersion` in `options.nix` (version in code, what's in Git)
- ✅ **Stable Version**: `stableVersion` in `options.nix` (tested, optional, defaults to `featureVersion`)
- ✅ **User's Current Version**: `config.features.*._version` (from user config)
- ✅ **Available Migrations**: Directory scan `migrations/vX-to-vY.nix`
- ✅ **Migration Chain**: Automatically found through directory scan
- ❌ **NO manual registry** - everything automatic!

**Version Definitions:**
- **`featureVersion`** = Version in code (what's currently in Git repository)
- **`stableVersion`** = Stable, tested version (optional, if not set = `featureVersion`)
- **User's `_version`** = What user currently has installed (from user config)
- **Available versions** = What's available in code (`featureVersion` and optionally `stableVersion`)

### Q: Where is version registry?
**A**: NO registry needed! Everything automatic:
- Versions from `options.nix` (Auto-Discovery)
- Migrations from `migrations/` directory (directory scan)

### Q: Should Command Center manage features?
**A**: NO - Features manage themselves, Command Center only routes

### Q: Should Command Center initialize configs?
**A**: NO - Features initialize their own configs

### Q: How are available versions determined?
**A**: Automatically from `options.nix` (Auto-Discovery) - reads `featureVersion` (code version) and `stableVersion` (stable, optional)

### Q: Where are versions stored? Duplicated?
**A**: NO - only in `options.nix`:
- ✅ **Code Version**: `featureVersion` in `options.nix` (version in code, what's in Git)
- ✅ **Stable Version**: `stableVersion` in `options.nix` (tested, optional, defaults to `featureVersion`)
- ✅ **User's Current Version**: `config.features.*._version` (from user config)
- ✅ **Available Versions**: Read automatically from `options.nix` (Auto-Discovery)
- ✅ **User can choose**: Code version (`featureVersion`) or Stable (`stableVersion`) or Pin (`version`)
- ❌ **NO version in `metadata.nix`** - only dependencies/conflicts!
- ✅ **No redundancy**: Versions are only defined in `options.nix`

**Where versions are defined:**
- **Code version**: `featureVersion` in `features/${name}/options.nix` (what's in Git)
- **Stable version**: `stableVersion` in `features/${name}/options.nix` (optional, defaults to `featureVersion`)
- **User's current version**: `config.features.${name}._version` (from user config)
- **Available versions**: Read automatically from `options.nix` (Auto-Discovery)

---

## 📋 Version Pinning (Optional)

### User can pin features to specific versions

**Use Case:**
- User wants to keep version 1.0 (don't auto-update)
- User wants to migrate to version 2.0 (not latest)

**Implementation:**

```nix
# features/system-discovery/options.nix
let
  latestVersion = "2.0";  # Latest version (bleeding edge, what's in Git)
  stableVersion = "1.5";  # Stable version (tested, optional, defaults to latestVersion)
in {
  options.features.system-discovery = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = latestVersion;
      internal = true;
      description = "Feature version (user's current version)";
    };
    
    version = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Pin to specific version (overrides auto-update and use-stable)";
    };
    
    use-stable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use stable version instead of latest version";
    };
    
    auto-update = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow automatic updates";
    };
  };
}
```

**User Config:**
```nix
# configs/system-config.nix
{
  features = {
    system-discovery = {
      # Option 1: Pin to specific version
      version = "1.0";  # Pin to version 1.0 (ignores code/stable versions)
      auto-update = false;  # Don't auto-update
      
      # Option 2: Use stable version
      # version = null;
      # use-stable = true;  # Use stableVersion (1.5) instead of latestVersion (2.0)
      # auto-update = true;  # Allow auto-update within stable channel
      
      # Option 3: Use latest version (default)
      # version = null;
      # use-stable = false;  # Use latestVersion (2.0) - latest version
      # auto-update = true;  # Allow auto-update to latest version
    };
  };
}
```

**Version Resolution:**
1. If `version` is set → use pinned version (ignores latest/stable versions, ignores auto-update)
2. If `version` is null AND `use-stable = true` → use `stableVersion` from `options.nix`
3. If `version` is null AND `use-stable = false` → use `latestVersion` from `options.nix` (latest version)
4. Auto-update only if `auto-update = true` AND `version` is null

**Downgrade Support:**
- ✅ User can pin to older version: `version = "1.5"` (even if current is 6.0)
- ✅ Migration supports downgrade: `6.0 → 1.5` (chain migrations backwards)
- ⚠️ **Warning**: Downgrades may lose data/features from newer versions
- ✅ User confirmation required for downgrades

**Migration to Specific Version (Upgrade or Downgrade):**
```bash
# Upgrade: 1.0 → 2.0
$ ncc update-features --feature=system-discovery --version=2.0

# Downgrade: 6.0 → 1.5
$ ncc update-features --feature=system-discovery --version=1.5
```

**What happens:**
1. Checks if migration exists (upgrade or downgrade)
2. Finds migration chain (e.g., 6.0 → 5.0 → 4.0 → ... → 1.5)
3. Runs migrations in sequence
4. Updates `version = "1.5"` in user config
5. Pins to version 1.5

**Downgrade Support:**
- ✅ Supports downgrading to older versions
- ✅ Chain migrations work backwards (6.0 → 5.0 → 4.0 → ... → 1.5)
- ✅ Each migration step is reversible
- ⚠️ **Warning**: Downgrades may lose data/features from newer versions

---

## ✅ Summary

**Auto-Discovery**: Features automatically recognized, `featureVersion` (code version) and `stableVersion` (stable, optional) read from `options.nix` ⭐ NEW!
**Version-Registry**: Auto-Discovery from `options.nix` - NO manual registry needed
**Version Pinning**: User can pin features to specific versions (optional)
**Command Center**: Only router, no feature management
**Config-Init**: Features initialize themselves
**Next Step**: Implement Auto-Discovery + create `feature-version-check.nix`

