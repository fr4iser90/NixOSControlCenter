# NixOS Control Center - Architecture Explanation

## How NixOS Modules Work

### Module Loading

1. **Module Import**: When a module is enabled in `module-manager-config.nix`, the module is imported via `modules/default.nix`
2. **Module Structure**: Every NixOS module has:
   - `options`: Define configuration options (with defaults)
   - `config`: Apply configuration (only evaluated if module is enabled)
   - `let` block: Always evaluated, even if module is disabled

3. **Evaluation Order**:
   ```
   Module Import → let block (ALWAYS) → options (ALWAYS) → config (ONLY if enabled)
   ```

### The Problem with `let` Block

**CRITICAL**: The `let` block is evaluated BEFORE `config`, and it's evaluated even if `cfg.enable = false`.

**Example of WRONG approach**:
```nix
let
  cfg = config.modules.system-discovery;
  # This is evaluated even if cfg.enable = false!
  script = pkgs.writeShellScriptBin "my-script" ''
    VALUE="${cfg.snapshotDir}"  # ❌ ERROR: cfg.snapshotDir is null when disabled!
  '';
in {
  config = mkIf cfg.enable {
    # Script is already created above, but cfg is incomplete
  };
}
```

**Why this fails**:
- When `cfg.enable = false`, `cfg` only contains `{ enable = false; }`
- All other options are `null` or not defined
- Scripts in `let` block try to access `cfg.snapshotDir` → `null` → Error

**CORRECT approach**:
```nix
let
  cfg = config.modules.system-discovery;
  # Only define things that don't depend on cfg options
in {
  config = mkIf cfg.enable {
    # Define scripts HERE, where cfg is fully evaluated
    let
      script = pkgs.writeShellScriptBin "my-script" ''
        VALUE="${cfg.snapshotDir}"  # ✅ OK: cfg is complete here
      '';
    in {
      # Use script here
    };
  };
}
```

## How Terminal-UI Works

### Terminal-UI Architecture

Terminal-UI is a **shared utility module** that provides:
- **Colored output**: Consistent color scheme across all modules
- **Formatted messages**: Info, success, warning, error messages
- **Text formatting**: Headers, subheaders, normal text
- **Badges**: Status badges for operations
- **Interactive components**: Prompts, spinners, progress bars
- **Tables and lists**: Structured data display

### Terminal-UI Module Structure

```nix
# nixos/modules/terminal-ui/default.nix
{ config, lib, ... }:

let
  cfg = config.modules.terminal-ui;
  colors = import ./colors.nix;
  
  # Core components (text, layout)
  core = import ./core { 
    inherit lib colors; 
    inherit (cfg) config;
  };
  
  # Status components (messages, badges)
  status = import ./status { 
    inherit lib colors; 
    inherit (cfg) config;
  };
  
  # Interactive components (prompts, spinners)
  interactive = import ./interactive { 
    inherit lib colors; 
    inherit (cfg) config;
  };
  
  # Component components (lists, tables, progress)
  components = import ./components { 
    inherit lib colors; 
    inherit (cfg) config;
  };

  # API definition - ALWAYS available
  apiValue = {
    inherit colors;
    inherit (core) text layout;
    inherit (components) lists tables progress boxes;
    inherit (interactive) prompts spinners;
    inherit (status) messages badges;
  };

in {
  options.modules.terminal-ui = {
    enable = lib.mkEnableOption "terminal UI";
    
    config = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Terminal UI configuration options";
    };

    # CRITICAL: API is ALWAYS available, even if enable = false
    api = lib.mkOption {
      type = lib.types.attrs;
      default = apiValue;
      description = "Terminal UI API für andere Features";
    };
  };

  config = {
    # API is ALWAYS available, not just when enable = true
    # This is evaluated regardless of enable status
    modules.terminal-ui.api = apiValue;
  };
}
```

### Why Terminal-UI API is Always Available

**Key Points**:

1. **API Defined in `let` Block**: The `apiValue` is created in the `let` block, which is **always evaluated**
2. **API Set in `config` Block**: The `api` option is set in the `config` block, which is **always evaluated** (not wrapped in `mkIf`)
3. **No Dependency on `enable`**: The API doesn't depend on `cfg.enable`, so it's always available
4. **Dependency Guarantee**: If a module depends on `terminal-ui` (in `metadata.nix`), the module is loaded first, ensuring API exists

**Evaluation Flow**:
```
1. terminal-ui module loaded (dependency)
2. let block evaluated → apiValue created
3. options defined → api option declared
4. config evaluated → api option set to apiValue (ALWAYS, not in mkIf)
5. Other modules can access config.modules.terminal-ui.api
```

### Terminal-UI API Structure

The API provides:

```nix
{
  # Colors
  colors = {
    primary = "...";
    success = "...";
    error = "...";
    # ... more colors
  };
  
  # Text formatting
  text = {
    header = "function";
    subHeader = "function";
    normal = "function";
    newline = "...";
  };
  
  # Messages
  messages = {
    info = "function";
    success = "function";
    warning = "function";
    error = "function";
  };
  
  # Badges
  badges = {
    success = "function";
    error = "function";
    info = "function";
  };
  
  # Layout
  layout = {
    # Layout functions
  };
  
  # Components
  lists = { ... };
  tables = { ... };
  progress = { ... };
  boxes = { ... };
  
  # Interactive
  prompts = { ... };
  spinners = { ... };
}
```

### How Terminal-UI is Passed to Features

**Method 1: Direct Access (RECOMMENDED)**

```nix
# In module
config = mkIf cfg.enable {
  let
    # ✅ Access directly from config
    ui = config.modules.terminal-ui.api;
  in {
    # Use ui here
  };
}
```

**Why this works**:
- `terminal-ui` is a dependency, so module is loaded first
- API is set in `config` block (always evaluated)
- No need to pass as parameter

**Method 2: Lambda Parameter (NOT RECOMMENDED)**

```nix
# ❌ DON'T DO THIS
{ config, lib, pkgs, ui, ... }:  # ui as parameter
```

**Why this is wrong**:
- NixOS modules don't receive custom parameters
- Standard parameters are: `config`, `lib`, `pkgs`, `systemConfig`, `...`
- `ui` would need to be passed manually, breaking module system

**Method 3: Fallback (NOT NEEDED)**

```nix
# ❌ DON'T DO THIS
let
  ui = config.modules.terminal-ui.api or (
    # Complex fallback
  );
```

**Why this is wrong**:
- `terminal-ui` is a dependency, so API is guaranteed to exist
- Fallback code is unnecessary
- Adds complexity and potential bugs

### Terminal-UI Dependency System

**In `metadata.nix`**:
```nix
"system-discovery" = {
  dependencies = [ "terminal-ui" "command-center" ];
};
```

**In `modules/default.nix`**:
```nix
# Dependency resolution ensures terminal-ui is loaded first
sortedFeatures = sortFeaturesByDependencies allFeatures;

# terminal-ui MUST be imported first if any module is active
terminalUIFirst = if hasAnyFeature && lib.elem "terminal-ui" allFeatures 
  then [ ./terminal-ui ] 
  else [];
otherModules = lib.filter (m: toString m != toString ./terminal-ui) moduleModules;

imports = terminalUIFirst ++ otherModules;
```

**Result**:
- `terminal-ui` module is loaded before any module that depends on it
- `terminal-ui` options are defined before other modules evaluate
- `terminal-ui.api` is available when other modules access it

### Terminal-UI Usage Patterns

**Pattern 1: In Scripts (CORRECT)**

```nix
config = mkIf cfg.enable {
  let
    ui = config.modules.terminal-ui.api;
    myScript = pkgs.writeShellScriptBin "my-command" ''
      #!${pkgs.bash}/bin/bash
      ${ui.messages.info "Starting operation..."}
      # ... do work
      ${ui.messages.success "Operation complete!"}
    '';
  in {
    # Use script
  };
}
```

**Pattern 2: In Nix Expressions (CORRECT)**

```nix
config = mkIf cfg.enable {
  let
    ui = config.modules.terminal-ui.api;
    message = ui.messages.info "Configuration loaded";
  in {
    # Use message in config
  };
}
```

**Pattern 3: Multiple Features (CORRECT)**

```nix
# Feature A
config = mkIf cfg.enable {
  let
    ui = config.modules.terminal-ui.api;  # ✅ Same API for all
  in { ... };
}

# Feature B
config = mkIf cfg.enable {
  let
    ui = config.modules.terminal-ui.api;  # ✅ Same API for all
  in { ... };
}
```

### Terminal-UI vs Echo

**WRONG - Using echo**:
```nix
myScript = pkgs.writeShellScriptBin "cmd" ''
  echo "Starting..."           # ❌ No colors, no formatting
  echo "Success!"              # ❌ Inconsistent with other modules
  echo "Error occurred"        # ❌ No error styling
'';
```

**CORRECT - Using terminal-ui**:
```nix
let
  ui = config.modules.terminal-ui.api;
in {
  myScript = pkgs.writeShellScriptBin "cmd" ''
    ${ui.messages.info "Starting..."}      # ✅ Colored, formatted
    ${ui.messages.success "Success!"}      # ✅ Consistent styling
    ${ui.messages.error "Error occurred"}  # ✅ Error styling
  '';
}
```

**Benefits**:
- Consistent output across all modules
- Colored messages for better readability
- Proper error/warning styling
- Unified user experience

### Terminal-UI Configuration

**Terminal-UI can be configured** (even though API is always available):

```nix
systemConfig.modules.terminal-ui = {
  enable = true;  # Enable terminal-ui module
  config = {
    # Configuration options
    colors = { ... };
    # ... more config
  };
};
```

**Important**: Even if `enable = false`, the `api` is still available! The `enable` option only controls whether terminal-ui's own modules are active, not the API availability.

### Terminal-UI Module Loading Order

**Critical Order**:

1. **terminal-ui** module loaded first (if any module depends on it)
2. **terminal-ui** `let` block evaluated → `apiValue` created
3. **terminal-ui** `options` defined → `api` option declared
4. **terminal-ui** `config` evaluated → `api` set to `apiValue`
5. **Other modules** loaded
6. **Other modules** can access `config.modules.terminal-ui.api`

**Why Order Matters**:
- If `terminal-ui` is loaded after a module that uses it, the API might not exist yet
- Dependency system ensures correct order
- `terminal-ui` is always loaded first if it's a dependency

### Terminal-UI Best Practices

1. **Always Access via config**: `ui = config.modules.terminal-ui.api;`
2. **No Fallbacks**: Don't use `or` fallback - API is guaranteed
3. **No Lambda Parameters**: Don't try to pass `ui` as parameter
4. **Use in mkIf Block**: Access `ui` in `mkIf cfg.enable` block where it's needed
5. **Consistent Usage**: Always use `ui.messages.*` instead of `echo`
6. **Dependency Declaration**: Always declare `terminal-ui` as dependency in `metadata.nix`

### Common Terminal-UI Mistakes

**Mistake 1: Fallback Code**
```nix
# ❌ WRONG
ui = config.modules.terminal-ui.api or (
  let
    colors = import ../../terminal-ui/colors.nix;
    # ... complex fallback
  in { ... }
);
```

**Why wrong**: `terminal-ui` is a dependency, API is guaranteed to exist

**Mistake 2: Accessing in let Block**
```nix
# ❌ WRONG (if module is disabled)
let
  cfg = config.modules.system-discovery;
  ui = config.modules.terminal-ui.api;  # OK, but...
  script = pkgs.writeShellScriptBin "..." ''
    ${ui.messages.info "..."}
    VALUE="${cfg.snapshotDir}"  # ❌ cfg is null when disabled!
  '';
in { ... }
```

**Why wrong**: Script uses `cfg` which is null when disabled. Move to `mkIf` block.

**Mistake 3: Not Using Terminal-UI**
```nix
# ❌ WRONG
script = pkgs.writeShellScriptBin "..." ''
  echo "Starting..."  # Should use ui.messages.info
'';
```

**Why wrong**: Inconsistent output, no colors, breaks user experience

### Terminal-UI Export Mechanism

**How API is Exported**:

1. **Created in `let` block**: `apiValue` is created from components
2. **Set as default**: `api` option has `default = apiValue`
3. **Set in `config`**: `modules.terminal-ui.api = apiValue` (always evaluated)
4. **Available via config**: Other modules access via `config.modules.terminal-ui.api`

**Key Code**:
```nix
let
  apiValue = {
    inherit colors;
    inherit (core) text layout;
    inherit (status) messages badges;
    # ... more
  };
in {
  options.modules.terminal-ui = {
    api = mkOption {
      default = apiValue;  # Default value
    };
  };
  
  config = {
    modules.terminal-ui.api = apiValue;  # Always set, not in mkIf!
  };
}
```

**Why this works**:
- `apiValue` is created in `let` block (always evaluated)
- `api` option is set in `config` block (always evaluated, not in `mkIf`)
- Result: API is always available, regardless of `enable` status

### Terminal-UI API Components

**Colors** (`ui.colors`):
```nix
{
  red = "\\e[31m";
  green = "\\e[32m";
  yellow = "\\e[33m";
  blue = "\\e[34m";
  cyan = "\\e[36m";
  bold = "\\e[1m";
  reset = "\\e[0m";
  # ... more colors
}
```

**Messages** (`ui.messages`):
```nix
{
  info = text: ''printf '%b\n' "${colors.cyan}[INFO]${colors.reset} ${text}"'';
  success = text: ''printf '%b\n' "${colors.green}[ OK ]${colors.reset} ${text}"'';
  warning = text: ''printf '%b\n' "${colors.yellow}[WARN]${colors.reset} ${text}"'';
  error = text: ''printf '%b\n' "${colors.red}[ERROR]${colors.reset} ${text}"'';
}
```

**Badges** (`ui.badges`):
```nix
{
  success = text: ''printf '%b' "${colors.green}✓${colors.reset} ${text}"'';
  error = text: ''printf '%b' "${colors.red}✘${colors.reset} ${text}"'';
  info = text: ''printf '%b' "${colors.cyan}ℹ${colors.reset} ${text}"'';
  warning = text: ''printf '%b' "${colors.yellow}⚠${colors.reset} ${text}"'';
}
```

**Text** (`ui.text`):
```nix
{
  header = text: ''printf '%b\n' "\n${colors.blue}=== ${text} ===${colors.reset}"'';
  subHeader = text: ''printf '%b\n' "\n${colors.cyan}--- ${text} ---${colors.reset}"'';
  normal = text: ''printf '%b\n' "${text}"'';
  newline = ''printf '\n' '';
  # ... more text functions
}
```

**Usage in Scripts**:
```nix
let
  ui = config.modules.terminal-ui.api;
  script = pkgs.writeShellScriptBin "cmd" ''
    #!${pkgs.bash}/bin/bash
    ${ui.messages.info "Starting operation"}
    ${ui.text.header "Processing"}
    ${ui.badges.success "Completed"}
    ${ui.messages.error "Failed"}
  '';
in { ... }
```

### Terminal-UI Export Summary

**How Terminal-UI Exports API**:

1. **Module Structure**:
   - `terminal-ui/default.nix` is the main module
   - Imports sub-modules: `core`, `status`, `components`, `interactive`
   - Creates `apiValue` in `let` block

2. **API Creation**:
   ```nix
   let
     colors = import ./colors.nix;
     core = import ./core { inherit lib colors; };
     status = import ./status { inherit lib colors; };
     # ... more imports
     
     apiValue = {
       inherit colors;
       inherit (core) text layout;
       inherit (status) messages badges;
       # ... more
     };
   in { ... }
   ```

3. **API Export**:
   ```nix
   config = {
     # ALWAYS evaluated, not in mkIf!
     modules.terminal-ui.api = apiValue;
   };
   ```

4. **Access by Other Features**:
   ```nix
   config = mkIf cfg.enable {
     let
       ui = config.modules.terminal-ui.api;  # ✅ Available here
     in { ... };
   };
   ```

**Key Points**:
- API is created in `let` block → always evaluated
- API is set in `config` block → always evaluated (not in `mkIf`)
- API doesn't depend on `enable` → always available
- Dependency system ensures `terminal-ui` loads first
- No fallback needed → API is guaranteed to exist

## How Command-Center Works

### Command-Center Architecture

Command-Center is the central CLI dispatcher for all NixOS Control Center commands. It provides:
- **Unified CLI**: Single `ncc` command for all modules
- **Command Discovery**: Automatically finds and registers commands from all enabled modules
- **Help System**: Built-in help and documentation for each command
- **Argument Parsing**: Handles command arguments and options

### Command-Center Module Structure

```nix
# nixos/modules/command-center/registry/default.nix
{
  options.modules.command-center = {
    commands = mkOption {
      type = lib.types.listOf types.commandType;
      default = [];
      description = "Available commands for the NixOS Control Center";
    };
    
    categories = mkOption {
      type = lib.types.listOf lib.types.str;
      default = usedCategories;  # Auto-detected from commands
      description = "Command categories";
    };
  };
}
```

### Command Type Definition

```nix
# nixos/modules/command-center/registry/types.nix
commandType = lib.types.submodule {
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Command name (used for execution)";
    };
    
    type = lib.mkOption {
      type = lib.types.enum [ "command" "manager" ];
      default = "command";
      description = "Command type: standalone or manager with subcommands";
    };
    
    description = lib.mkOption {
      type = lib.types.str;
      description = "Short description";
    };
    
    script = lib.mkOption {
      type = lib.types.path;
      description = "Executable script path";
    };
    
    category = lib.mkOption {
      type = lib.types.str;
      default = "other";
      description = "Command category for grouping";
    };
    
    arguments = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Allowed arguments";
    };
    
    dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Required modules or packages";
    };
    
    shortHelp = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "One-line help text";
    };
    
    longHelp = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Detailed help text";
    };
  };
}
```

### Command Execution Flow

1. **User runs**: `ncc discover`
2. **CLI dispatcher** (`ncc` script):
   - Loads all registered commands from `config.modules.command-center.commands`
   - Finds command with `name = "discover"`
   - Executes the `script` path with remaining arguments
3. **Script execution**:
   - Script is a `pkgs.writeShellScriptBin` created package
   - Runs with all provided arguments
   - Uses `ui.messages.*` for output

### Command Registration Process

**Step 1: Feature Module Registers Command**

```nix
# In module (e.g., system-discovery/default.nix)
config = mkIf cfg.enable {
  let
    discoverScript = pkgs.writeShellScriptBin "ncc-discover-main" ''
      #!${pkgs.bash}/bin/bash
      # Script content
    '';
  in {
    modules.command-center.commands = [
      {
        name = "discover";
        description = "Scan system and create encrypted snapshot";
        category = "system";
        script = "${discoverScript}/bin/ncc-discover-main";
        arguments = [];
        dependencies = [];
        shortHelp = "discover - Scan system state";
        longHelp = ''Detailed help...'';
      }
    ];
  };
}
```

**Step 2: Command-Center Collects All Commands**

- All modules that register commands add them to `modules.command-center.commands`
- Command-Center module merges all commands into a single list
- Categories are auto-detected from command categories

**Step 3: CLI Dispatcher Uses Commands**

```nix
# nixos/modules/command-center/cli/default.nix
let
  commands = config.modules.command-center.commands;
  
  # Create ncc script that:
  # 1. Parses arguments
  # 2. Finds matching command
  # 3. Executes command script
  nccScript = pkgs.writeShellScriptBin "ncc" ''
    #!${pkgs.bash}/bin/bash
    
    COMMAND_NAME="$1"
    shift
    
    # Find command
    COMMAND=$(findCommand "$COMMAND_NAME")
    
    # Execute command script
    exec "$COMMAND_SCRIPT" "$@"
  '';
in {
  environment.systemPackages = [ nccScript ];
}
```

### When Commands are Registered

**CRITICAL**: Commands must be registered in `mkIf cfg.enable` block!

**Why?**
- If registered in `let` block: Commands are registered even when module is disabled
- Scripts might not exist (if created in `mkIf` block)
- Or scripts exist but use `null` cfg values (if created in `let` block)

**WRONG - Commands in let block**:
```nix
let
  cfg = config.modules.system-discovery;
  discoverScript = pkgs.writeShellScriptBin "..." ''...'';  # ❌ Created even if disabled
  
  # ❌ Command registered even if module disabled!
  commands = [
    { name = "discover"; script = "${discoverScript}/bin/..."; }
  ];
in {
  config = mkIf cfg.enable {
    # Script might use null cfg values
    modules.command-center.commands = commands;
  };
}
```

**WRONG - Scripts in let, commands in mkIf**:
```nix
let
  cfg = config.modules.system-discovery;
  discoverScript = pkgs.writeShellScriptBin "..." ''
    VALUE="${cfg.snapshotDir}"  # ❌ ERROR: null when disabled!
  '';
in {
  config = mkIf cfg.enable {
    modules.command-center.commands = [
      { script = "${discoverScript}/bin/..."; }  # Script already created with null values
    ];
  };
}
```

**CORRECT - Everything in mkIf**:
```nix
let
  cfg = config.modules.system-discovery;
  # ✅ Only things that don't depend on cfg
in {
  config = mkIf cfg.enable {
    let
      ui = config.modules.terminal-ui.api;
      discoverScript = pkgs.writeShellScriptBin "ncc-discover-main" ''
        #!${pkgs.bash}/bin/bash
        VALUE="${cfg.snapshotDir}"  # ✅ cfg is complete here
        ${ui.messages.info "Starting..."}
      '';
    in {
      # ✅ Commands registered only when module enabled
      modules.command-center.commands = [
        {
          name = "discover";
          description = "Scan system";
          category = "system";
          script = "${discoverScript}/bin/ncc-discover-main";
          arguments = [];
          dependencies = [];
          shortHelp = "discover - Scan system state";
          longHelp = ''Detailed help...'';
        }
      ];
    };
  };
}
```

### Command Discovery and Help

**Command List** (`ncc` or `ncc help`):
- Iterates through all registered commands
- Groups by category
- Shows name and shortHelp

**Command Help** (`ncc help <command>`):
- Finds command by name
- Displays longHelp
- Shows available arguments

**Command Execution** (`ncc <command> [args]`):
- Finds command by name
- Validates arguments (if implemented)
- Executes script with arguments

### Command-Center Dependencies

**Command-Center itself**:
- Depends on `terminal-ui` for output formatting
- Provides `modules.command-center.commands` option
- Creates `ncc` CLI dispatcher script

**Features using Command-Center**:
- Must have `command-center` in dependencies (metadata.nix)
- Register commands in `modules.command-center.commands`
- Scripts must be created when module is enabled

### Command-Center Best Practices

1. **Register in mkIf**: Always register commands in `mkIf cfg.enable` block
2. **Create scripts in mkIf**: Scripts should be created in same `mkIf` block
3. **Use terminal-ui**: All output should use `ui.messages.*`, not `echo`
4. **Complete command info**: Provide name, description, category, help text
5. **Script naming**: Use `ncc-<command>-main` pattern for script names
6. **Argument validation**: Scripts should validate their own arguments

### Command-Center vs Direct Scripts

**Command-Center approach** (RECOMMENDED):
```nix
modules.command-center.commands = [
  { name = "discover"; script = "${script}/bin/..."; }
];
# User runs: ncc discover
```

**Direct script approach** (NOT RECOMMENDED):
```nix
environment.systemPackages = [ discoverScript ];
# User runs: ncc-discover (inconsistent naming)
```

**Why Command-Center is better**:
- Unified CLI (`ncc` for everything)
- Consistent naming
- Built-in help system
- Automatic command discovery
- Category grouping

## How System-Discovery Should Work

### Correct Structure

```nix
{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.modules.system-discovery;
  # ✅ Only define things that don't depend on cfg options
in {
  options.modules.system-discovery = {
    # Define all options with defaults
    enable = mkEnableOption "system discovery";
    snapshotDir = mkOption {
      type = types.str;
      default = "/var/lib/nixos-control-center/snapshots";
    };
    # ... more options
  };

  config = mkMerge [
    # Map systemConfig to config
    {
      modules.system-discovery = {
        enable = mkDefault (systemConfig.modules.system-discovery or false);
      };
    }

    # Feature implementation (only when enabled)
    (mkIf cfg.enable {
      let
        # ✅ Get terminal-ui API (simple, no fallback)
        ui = config.modules.terminal-ui.api;
        
        # ✅ Import scanners (only when enabled)
        desktopScanner = import ./scanners/desktop.nix { inherit pkgs; };
        # ... other scanners
        
        # ✅ Create handlers (only when enabled)
        snapshotGenerator = import ./snapshot-generator.nix {
          inherit pkgs cfg;
          scanners = { ... };
        };
        # ... other handlers
        
        # ✅ Create scripts (only when enabled)
        discoverScript = pkgs.writeShellScriptBin "ncc-discover-main" ''
          #!${pkgs.bash}/bin/bash
          ${ui.messages.info "Starting..."}  # ✅ Use ui, not echo
          # ... script content using cfg (which is now complete)
        '';
        # ... other scripts
      in {
        # ✅ Register commands
        modules.command-center.commands = [
          {
            name = "discover";
            script = "${discoverScript}/bin/ncc-discover-main";
            # ...
          }
          # ... more commands
        ];
        
        # ✅ System configuration
        systemd.tmpfiles.rules = [
          "d ${cfg.snapshotDir} 0755 root root -"
        ];
        # ... more config
      };
    })
  ];
}
```

## How Dependencies Work

### Dependency Resolution

1. **Metadata Definition** (`metadata.nix`):
   ```nix
   "system-discovery" = {
     dependencies = [ "terminal-ui" "command-center" ];
   };
   ```

2. **Dependency Resolution** (`modules/default.nix`):
   - When `system-discovery` is enabled, dependencies are automatically resolved
   - `terminal-ui` and `command-center` are loaded first
   - This ensures their options are available when `system-discovery` is evaluated

3. **Module Loading Order**:
   ```
   1. terminal-ui (dependency) → options defined → config evaluated
   2. command-center (dependency) → options defined → config evaluated
   3. system-discovery → options defined → config evaluated
   ```

### Why Dependencies Matter

- **Terminal-UI**: Provides `config.modules.terminal-ui.api` which is always available
- **Command-Center**: Provides `modules.command-center.commands` option for command registration
- **No Fallbacks Needed**: Dependencies guarantee that required options exist

## Why Terminal-UI is Not Passed in Lambda

### Lambda Parameters

```nix
{ config, lib, pkgs, systemConfig, ... }:
```

**Why `ui` is not a parameter**:
1. **NixOS Module System**: Modules receive standard parameters (`config`, `lib`, `pkgs`, etc.)
2. **Access via config**: Terminal-UI API is accessed via `config.modules.terminal-ui.api`
3. **Dependency Guarantee**: Since `terminal-ui` is a dependency, the API is always available
4. **No Need for Lambda Parameter**: We can access it directly from `config`

### Correct Access Pattern

```nix
{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = config.modules.system-discovery;
in {
  config = mkIf cfg.enable {
    let
      # ✅ Access terminal-ui API from config
      ui = config.modules.terminal-ui.api;
    in {
      # Use ui here
    };
  };
}
```

## Common Mistakes and Solutions

### Mistake 1: Scripts in `let` Block

**Problem**: Scripts created even when module is disabled, accessing `null` cfg values

**Solution**: Move scripts into `mkIf cfg.enable` block

### Mistake 2: Terminal-UI Fallback

**Problem**: Unnecessary fallback code when terminal-ui is a dependency

**Solution**: Simply use `config.modules.terminal-ui.api`

### Mistake 3: Echo Instead of UI

**Problem**: Using `echo` instead of `ui.messages.*` for output

**Solution**: Replace all `echo` with `ui.messages.info`, `ui.messages.success`, etc.

### Mistake 4: Imports in `let` Block

**Problem**: Importing scanner/handler modules even when module is disabled

**Solution**: Move imports into `mkIf cfg.enable` block

## Summary

1. **`let` Block**: Only for things that don't depend on `cfg` options
2. **`mkIf cfg.enable` Block**: Everything that depends on `cfg` goes here
3. **Terminal-UI**: Simple access via `config.modules.terminal-ui.api`, no fallback
4. **Dependencies**: Guarantee that required options exist
5. **Scripts**: Created only when module is enabled, inside `mkIf cfg.enable`
6. **UI Output**: Always use `ui.messages.*`, never `echo`

## Official Sources and References

### NixOS Module System Documentation

1. **Official NixOS Manual - Module System**:
   - URL: https://nixos.org/manual/nixos/
   - Section: Module System
   - Explains: Module structure, options, config, mkIf

2. **NixOS Wiki - Modules**:
   - URL: https://nixos.wiki/wiki/NixOS_modules
   - Explains: Module structure, best practices, mkIf usage

3. **Nix.dev - Module System Tutorial**:
   - URL: https://nix.dev/tutorials/module-system/index.html
   - Explains: How to create modules, best practices

4. **Nix.dev - Best Practices**:
   - URL: https://nix.dev/guides/best-practices.html
   - Explains: General Nix best practices

### Key Points from Official Documentation

**From NixOS Manual and Wiki**:
- Modules have three parts: `imports`, `options`, `config`
- Use `mkIf` for conditional configuration
- Options are declared with `mkOption` and have defaults
- `config` block is where actual configuration happens

**From Nix.dev Tutorial**:
- Use `let` blocks for local bindings
- Use `mkIf` to conditionally apply configuration
- Avoid accessing config values in `let` block when they might be null

**Evaluation Order (Inferred from NixOS Behavior)**:
1. Module is imported
2. `let` block is evaluated (ALWAYS, even if module disabled)
3. `options` are declared (ALWAYS)
4. `config` block is evaluated (ONLY if conditions in `mkIf` are met)

### Why This Matters

The official documentation shows examples like:
```nix
let
  cfg = config.services.example;
in {
  config = mkIf cfg.enable {
    # Configuration here
  };
}
```

**But they don't show**:
```nix
let
  cfg = config.services.example;
  script = pkgs.writeShellScriptBin "..." ''
    VALUE="${cfg.port}"  # ❌ This fails if enable = false
  '';
in {
  config = mkIf cfg.enable {
    # Use script here
  };
}
```

**The correct pattern** (following official examples):
```nix
let
  cfg = config.services.example;
in {
  config = mkIf cfg.enable {
    let
      script = pkgs.writeShellScriptBin "..." ''
        VALUE="${cfg.port}"  # ✅ cfg is complete here
      '';
    in {
      # Use script here
    };
  };
}
```

### Real-World Examples

Check official NixOS modules in the repository:
- URL: https://github.com/NixOS/nixpkgs/tree/nixos-unstable/nixos/modules
- Examples: `services/nginx`, `services/postgresql`, etc.
- Pattern: They use `mkIf` in `config` block, not in `let` block

### Conclusion

The approach described in this document follows:
1. Official NixOS module structure patterns
2. Best practices from nix.dev
3. Real-world examples from nixpkgs repository
4. Logical consequences of Nix evaluation order

The specific issue with `let` block evaluation is a **logical consequence** of how Nix evaluates expressions, even if not explicitly documented in every tutorial.

