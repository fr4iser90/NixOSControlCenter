# Network Module Migration: v0 → v1

## Overview

**Status**: ❌ v0 (old template) → ✅ v1 (new template per DEV.md)

**Goal**: Complete migration of the Network module to the new module template according to `nixos/features/.TEMPLATE/DEV.md`

**Critical**: All code must use System-Manager API (`config.core.system-manager.api.configHelpers`) - NO direct Bash/Nix syntax mixing!

---

## 1. Current Structure (v0) - Analysis

### Existing Files:
```
nixos/core/network/
├── default.nix              ❌ Contains implementation (should only have imports)
├── firewall.nix             ✅ Sub-module (stays)
├── networkmanager.nix       ✅ Sub-module (stays)
├── lib/
│   └── rules.nix            ✅ Library (stays)
└── recommendations/
    └── services.nix         ✅ Recommendations (stays)
```

### Problems (v0):
- ❌ **No `options.nix`** - Options completely missing
- ❌ **No `config.nix`** - Implementation directly in `default.nix`
- ❌ **No `user-configs/`** - No user-editable config
- ❌ **No versioning** - No `_version` field
- ❌ **Direct implementation** - `default.nix` contains `config = { ... }` blocks
- ❌ **No symlink management** - No symlink to `/etc/nixos/configs/`
- ❌ **Outdated config access** - Uses `systemConfig.enableFirewall` directly instead of `systemConfig.network`
- ❌ **No System-Manager API usage** - Missing proper API integration

### Current Config Access (v0):
```nix
# default.nix (v0)
networking = {
  hostName = systemConfig.hostName;  # ❌ Should come from network-config
  firewall.enable = systemConfig.enableFirewall or false;  # ❌ Outdated
};

# firewall.nix (v0)
services = systemConfig.networking.services or {};  # ❌ Structure missing
trustedNetworks = systemConfig.networking.firewall.trustedNetworks or [];  # ❌ Structure missing

# networkmanager.nix (v0)
wifi.powersave = systemConfig.enablePowersave or false;  # ❌ Outdated
dns = systemConfig.networkManager.dns or "default";  # ❌ Structure missing
```

---

## 2. Target Structure (v1) - Per DEV.md Template

### New Structure:
```
nixos/core/network/
├── README.md                 ✅ New: Documentation
├── default.nix               ✅ Refactored: Only imports
├── options.nix               ✅ New: All options + versioning
├── config.nix                ✅ New: Implementation + symlink management
├── firewall.nix              ✅ Stays: Sub-module
├── networkmanager.nix        ✅ Stays: Sub-module
├── user-configs/             ✅ New: User-editable configs
│   └── network-config.nix    ✅ New: Main config (symlinked to /etc/nixos/configs/)
├── lib/
│   └── rules.nix             ✅ Stays: Library
└── recommendations/
    └── services.nix          ✅ Stays: Recommendations
```

---

## 3. Migration Plan - Step by Step

### Phase 1: Preparation & Analysis ✅

- [x] Current structure analyzed
- [x] Target structure defined
- [x] Config migration checked (`v0-to-v1.nix`)
- [x] System-Manager API reviewed

### Phase 2: Create New Files

#### 2.1 Create `options.nix`
**Purpose**: Define all Network module options + versioning

**Content**:
- `_version = "1.0"` (REQUIRED)
- `enable` (optional, for Core modules)
- `hostName` (migrated from system-config)
- `firewall.enable` (migrated from `enableFirewall`)
- `firewall.allowPing`
- `firewall.trustedNetworks`
- `firewall.services` (service-specific firewall rules)
- `networkManager.enable`
- `networkManager.wifi.powersave` (migrated from `enablePowersave`)
- `networkManager.wifi.scanRandMacAddress`
- `networkManager.dns` (migrated from `networkManager.dns`)
- `timeZone` (from system-config, but should actually be in localization)

**Optionen-Struktur**:
```nix
options.systemConfig.network = {
  _version = "1.0";
  enable = lib.mkOption { ... };  # Optional für Core
  hostName = lib.mkOption { ... };
  firewall = {
    enable = lib.mkOption { ... };
    allowPing = lib.mkOption { ... };
    trustedNetworks = lib.mkOption { ... };
    services = lib.mkOption { ... };
  };
  networkManager = {
    enable = lib.mkOption { ... };
    wifi = {
      powersave = lib.mkOption { ... };
      scanRandMacAddress = lib.mkOption { ... };
    };
    dns = lib.mkOption { ... };
  };
    timeZone = lib.mkOption { ... };  # TODO: Should go to localization?
};
```

#### 2.2 Create `user-configs/network-config.nix`
**Purpose**: User-editable config (will be symlinked to `/etc/nixos/configs/network-config.nix`)

**Default Content**:
```nix
{
  network = {
    hostName = "nixos";
    firewall = {
      enable = false;
      allowPing = true;
      trustedNetworks = [];
      services = {};
    };
    networkManager = {
      enable = true;
      wifi = {
        powersave = false;
        scanRandMacAddress = true;
      };
      dns = "default";
    };
    timeZone = "Europe/Berlin";
  };
}
```

#### 2.3 Create `config.nix`
**Purpose**: All implementation logic (move from `default.nix`)

**Content**:
- Symlink management (like in `desktop/config.nix`)
- Default config creation (via System-Manager API)
- System configuration (networking, firewall, networkManager, time)
- Assertions
- Sub-module imports (firewall.nix, networkmanager.nix)

**Pattern** (like Desktop module - using System-Manager API):
```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.network or {};
  # CRITICAL: Use absolute path to deployed location, not relative
  userConfigFile = "/etc/nixos/core/network/user-configs/network-config.nix";
  symlinkPath = "/etc/nixos/configs/network-config.nix";
  # Use System-Manager API (like cli-formatter.api)
  configHelpers = config.core.system-manager.api.configHelpers;
  defaultConfig = ''
{
  network = {
    hostName = "nixos";
    firewall = {
      enable = false;
      allowPing = true;
      trustedNetworks = [];
      services = {};
    };
    networkManager = {
      enable = true;
      wifi = {
        powersave = false;
        scanRandMacAddress = true;
      };
      dns = "default";
    };
    timeZone = "Europe/Berlin";
  };
}
'';
in
  lib.mkMerge [
    {
      # Create symlink on activation (always, not only when enabled)
      # Uses central API from system-manager (professional pattern)
      system.activationScripts.network-config-symlink = 
        configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
    }
    (lib.mkIf (cfg.enable or true) {  # Network is Core, enabled by default
      # System-Configuration
      # Sub-Module-Imports
      # Assertions
    })
  ];
```

**Critical Notes**:
- ✅ Use `config.core.system-manager.api.configHelpers` (System-Manager API)
- ✅ Use absolute paths: `/etc/nixos/core/network/user-configs/network-config.nix`
- ✅ Use `configHelpers.setupConfigFile` (handles default creation + symlink)
- ❌ NO direct Bash/Nix syntax mixing
- ❌ NO manual `mkdir -p` or `ln -sfn` in activation scripts

#### 2.4 Refactor `default.nix`
**Purpose**: Only imports, no implementation

**New Structure**:
```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.network or {};
in {
  imports = [
    ./options.nix  # Always import options first
  ] ++ (if (cfg.enable or true) then [
    ./firewall.nix
    ./networkmanager.nix
    ./config.nix  # Implementation
  ] else [
    ./config.nix  # Import even if disabled (for symlink management)
  ]);
}
```

#### 2.5 Create `README.md`
**Purpose**: Network module documentation

**Content**:
- Overview
- Options documentation
- Usage examples
- Firewall configuration
- NetworkManager configuration
- Service-specific firewall rules

### Phase 3: Adapt Sub-Modules

#### 3.1 Adapt `firewall.nix`
**Changes**:
- Change config access: `systemConfig.networking.services` → `systemConfig.network.firewall.services`
- Change config access: `systemConfig.networking.firewall.trustedNetworks` → `systemConfig.network.firewall.trustedNetworks`
- Remove `systemConfig.enableFirewall` (becomes `systemConfig.network.firewall.enable`)

**Before (v0)**:
```nix
services = systemConfig.networking.services or {};
trustedNetworks = systemConfig.networking.firewall.trustedNetworks or [];
firewall.enable = lib.mkDefault true;  # ❌ Should come from cfg
```

**After (v1)**:
```nix
let
  cfg = systemConfig.network or {};
  firewallCfg = cfg.firewall or {};
in {
  networking.firewall = {
    enable = firewallCfg.enable or false;  # ✅ From cfg
    allowPing = firewallCfg.allowPing or true;
    # ...
  };
  # services from cfg.firewall.services
  # trustedNetworks from cfg.firewall.trustedNetworks
}
```

#### 3.2 Adapt `networkmanager.nix`
**Changes**:
- Change config access: `systemConfig.enablePowersave` → `systemConfig.network.networkManager.wifi.powersave`
- Change config access: `systemConfig.networkManager.dns` → `systemConfig.network.networkManager.dns`
- Check `systemConfig.network.networkManager.enable`

**Before (v0)**:
```nix
wifi.powersave = systemConfig.enablePowersave or false;  # ❌
dns = systemConfig.networkManager.dns or "default";  # ❌
```

**After (v1)**:
```nix
let
  cfg = systemConfig.network or {};
  nmCfg = cfg.networkManager or {};
in {
  networking.networkmanager = {
    enable = nmCfg.enable or true;
    wifi.powersave = nmCfg.wifi.powersave or false;  # ✅
    wifi.scanRandMacAddress = nmCfg.wifi.scanRandMacAddress or true;
    dns = nmCfg.dns or "default";  # ✅
  };
}
```

### Phase 4: Check Config Migration

#### 4.1 Check `v0-to-v1.nix` Migration
**Currently in `config-schema/migrations/v0-to-v1.nix`**:
```nix
"enableFirewall" = {
  targetFile = "configs/network-config.nix";
  structure = {
    enableFirewall = "enableFirewall";  # ❌ Should be network.firewall.enable
    enablePowersave = "enablePowersave";  # ❌ Should be network.networkManager.wifi.powersave
    networkManager = {
      dns = "networkManager.dns";  # ❌ Should be network.networkManager.dns
    };
  };
};
```

**Correction needed**:
```nix
"enableFirewall" = {
  targetFile = "configs/network-config.nix";
  structure = {
    network = {
      firewall = {
        enable = "enableFirewall";  # ✅ Correctly nested
      };
      networkManager = {
        wifi = {
          powersave = "enablePowersave";  # ✅ Correctly nested
        };
        dns = "networkManager.dns";  # ✅ Correctly nested
      };
    };
  };
};
```

#### 4.2 `hostName` Migration
**Problem**: `hostName` is currently directly in `system-config.nix`, should be `network.hostName`

**Solution**: Add migration to `v0-to-v1.nix`:
```nix
"hostName" = {
  targetFile = "configs/network-config.nix";
  structure = {
    network = {
      hostName = "hostName";
    };
  };
};
```

#### 4.3 `timeZone` Migration
**Problem**: `timeZone` is currently directly in `system-config.nix`, should actually be `localization.timeZone`, but Network module also uses it

**Solution**: 
- Option 1: Keep `timeZone` in Network module (if Network module uses it)
- Option 2: Migrate `timeZone` to Localization module (better, but Network module must then use `systemConfig.localization.timeZone`)

**Recommendation**: Option 2 (to Localization), but Network module can use fallback:
```nix
time.timeZone = cfg.timeZone or systemConfig.localization.timeZone or "UTC";
```

### Phase 5: Testing & Validation

#### 5.1 Build Test
- [ ] `nixos-rebuild dry-run` successful
- [ ] No syntax errors
- [ ] All options correctly defined
- [ ] System-Manager API accessible

#### 5.2 Config Migration Test
- [ ] Old `system-config.nix` correctly migrated
- [ ] `network-config.nix` created
- [ ] Symlink correctly created
- [ ] Default config created if missing

#### 5.3 Functionality Test
- [ ] NetworkManager works
- [ ] Firewall rules correctly applied
- [ ] Service-specific firewall rules work
- [ ] Trusted Networks work

---

## 4. Detailed File Changes

### 4.1 `options.nix` (NEW)

```nix
{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.network = {
    # Versionierung (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Network module version";
    };

    # Enable (optional für Core-Module)
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;  # Network ist Core, standardmäßig enabled
      description = "Enable network configuration";
    };

    # Hostname
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "System hostname";
    };

    # Firewall-Konfiguration
    firewall = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable firewall";
      };

      allowPing = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow ping requests";
      };

      trustedNetworks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of trusted network CIDR ranges";
        example = [ "10.0.0.0/8" "192.168.1.0/24" ];
      };

      services = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            exposure = lib.mkOption {
              type = lib.types.enum [ "local" "public" ];
              default = "local";
              description = "Service exposure level";
            };
          };
        });
        default = {};
        description = "Service-specific firewall rules";
        example = {
          ssh = { exposure = "local"; };
          nginx = { exposure = "public"; };
        };
      };
    };

    # NetworkManager-Konfiguration
    networkManager = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NetworkManager";
      };

      wifi = {
        powersave = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable WiFi power saving";
        };

        scanRandMacAddress = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Randomize MAC address during scanning";
        };
      };

      dns = lib.mkOption {
        type = lib.types.str;
        default = "default";
        description = "DNS configuration";
        example = "systemd-resolved";
      };
    };

    # Timezone (TODO: Should go to localization?)
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Berlin";
      description = "System timezone";
    };
  };
}
```

### 4.2 `user-configs/network-config.nix` (NEW)

```nix
{
  network = {
    hostName = "nixos";
    firewall = {
      enable = false;
      allowPing = true;
      trustedNetworks = [];
      services = {};
    };
    networkManager = {
      enable = true;
      wifi = {
        powersave = false;
        scanRandMacAddress = true;
      };
      dns = "default";
    };
    timeZone = "Europe/Berlin";
  };
}
```

### 4.3 `config.nix` (NEW)

```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.network or {};
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/core/network/user-configs/network-config.nix";
  symlinkPath = "/etc/nixos/configs/network-config.nix";
  # Use System-Manager API (like cli-formatter.api)
  configHelpers = config.core.system-manager.api.configHelpers;
  defaultConfig = ''
{
  network = {
    hostName = "nixos";
    firewall = {
      enable = false;
      allowPing = true;
      trustedNetworks = [];
      services = {};
    };
    networkManager = {
      enable = true;
      wifi = {
        powersave = false;
        scanRandMacAddress = true;
      };
      dns = "default";
    };
    timeZone = "Europe/Berlin";
  };
}
'';
in
  lib.mkMerge [
    {
      # Create symlink on activation (always, not only when enabled)
      # Uses central API from system-manager (professional pattern)
      system.activationScripts.network-config-symlink = 
        configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
    }
    (lib.mkIf (cfg.enable or true) {
      # Basic networking configuration
      networking = {
        hostName = cfg.hostName or "nixos";
        networkmanager.enable = cfg.networkManager.enable or true;
      };

      # Time zone configuration
      time.timeZone = cfg.timeZone or "Europe/Berlin";

      # Import sub-modules
      imports = [
        ./firewall.nix
        ./networkmanager.nix
      ];

      # Assertions
      assertions = [
        {
          assertion = (cfg.hostName or "") != "";
          message = "Network hostName must be specified";
        }
        {
          assertion = (cfg.timeZone or "") != "";
          message = "Network timeZone must be specified";
        }
      ];
    })
  ];
```

**Critical**: Uses System-Manager API - NO direct Bash/Nix syntax mixing!

### 4.4 `default.nix` (REFACTORED)

```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.network or {};
in {
  imports = [
    ./options.nix  # Always import options first
  ] ++ (if (cfg.enable or true) then [
    ./config.nix  # Implementation
  ] else [
    ./config.nix  # Import even if disabled (for symlink management)
  ]);
}
```

### 4.5 `firewall.nix` (ADAPTED)

```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.network or {};
  firewallCfg = cfg.firewall or {};
  recommendations = import ./recommendations/services.nix;
  rules = import ./lib/rules.nix { inherit lib; };
  
  # Service-Konfigurationen aus network.firewall.services
  services = firewallCfg.services or {};

  # Helper für sicheres Prüfen der Exposure
  isPubliclyExposed = userCfg:
    (userCfg.exposure or "local") == "public";
in {
  networking.firewall = {
    enable = firewallCfg.enable or false;
    allowPing = firewallCfg.allowPing or true;

    extraCommands = ''
      # Lösche existierende Regeln
      iptables -F

      # Standardregeln
      iptables -P INPUT DROP
      iptables -P FORWARD DROP
      iptables -P OUTPUT ACCEPT

      # Erlaube etablierte Verbindungen
      iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
      iptables -A INPUT -i lo -j ACCEPT

      # Service-spezifische Regeln
      ${lib.concatMapStrings (service: 
        rules.generateServiceRules service recommendations.${service} (services.${service} or {})
      ) (builtins.attrNames recommendations)}

      # Zusätzliche vertrauenswürdige Netze
      ${lib.concatMapStrings (net: ''
        iptables -A INPUT -s ${net} -j ACCEPT
      '') (firewallCfg.trustedNetworks or [])}
    '';
  };

  # Warnungen für unsichere Konfigurationen
  warnings = lib.flatten (map (service:
    let
      recCfg = recommendations.${service};
      userCfg = services.${service} or {};
    in
    if isPubliclyExposed userCfg && (recCfg.recommended or "local") == "local"
    then [ "Warning: ${service} is exposed publicly but recommended to be local only (${recCfg.reason or "security risk"})" ]
    else []
  ) (builtins.attrNames recommendations));
}
```

### 4.6 `networkmanager.nix` (ADAPTED)

```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.network or {};
  nmCfg = cfg.networkManager or {};
in {
  networking = {
    useDHCP = false;
    useNetworkd = false;

    networkmanager = {
      enable = nmCfg.enable or true;
      wifi.powersave = nmCfg.wifi.powersave or false;
      wifi.scanRandMacAddress = nmCfg.wifi.scanRandMacAddress or true;
      dns = nmCfg.dns or "default";
    };
  };
}
```

### 4.7 `config-schema/migrations/v0-to-v1.nix` (CORRECTION)

**Before**:
```nix
"enableFirewall" = {
  targetFile = "configs/network-config.nix";
  structure = {
    enableFirewall = "enableFirewall";
    enablePowersave = "enablePowersave";
    networkManager = {
      dns = "networkManager.dns";
    };
  };
};
```

**After**:
```nix
"enableFirewall" = {
  targetFile = "configs/network-config.nix";
  structure = {
    network = {
      firewall = {
        enable = "enableFirewall";
      };
      networkManager = {
        wifi = {
          powersave = "enablePowersave";
        };
        dns = "networkManager.dns";
      };
    };
  };
};

"hostName" = {
  targetFile = "configs/network-config.nix";
  structure = {
    network = {
      hostName = "hostName";
    };
  };
};
```

---

## 5. Checklist

### Preparation
- [x] Current structure analyzed
- [x] Target structure defined
- [x] Migration plan created
- [x] System-Manager API reviewed

### Create Files
- [ ] Create `options.nix`
- [ ] Create `user-configs/network-config.nix`
- [ ] Create `config.nix` (using System-Manager API)
- [ ] Create `README.md`

### Refactor Files
- [ ] Refactor `default.nix` (only imports)
- [ ] Adapt `firewall.nix` (config access)
- [ ] Adapt `networkmanager.nix` (config access)

### Config Migration
- [ ] Fix `v0-to-v1.nix` (nested structure)
- [ ] Add `hostName` migration
- [ ] Check `timeZone` migration (to localization?)

### Testing
- [ ] Build test (`nixos-rebuild dry-run`)
- [ ] Config migration test
- [ ] Functionality test
- [ ] System-Manager API test

### Documentation
- [ ] Complete `README.md`
- [ ] Document options
- [ ] Add examples

---

## 6. Important Notes

### 6.1 Config Access Pattern
**Before (v0)**:
```nix
systemConfig.enableFirewall
systemConfig.enablePowersave
systemConfig.networkManager.dns
systemConfig.networking.services
```

**After (v1)**:
```nix
systemConfig.network.firewall.enable
systemConfig.network.networkManager.wifi.powersave
systemConfig.network.networkManager.dns
systemConfig.network.firewall.services
```

### 6.2 Symlink Management
- Symlink is automatically created by `config.nix` via System-Manager API
- User edits `/etc/nixos/configs/network-config.nix` (symlink)
- Changes are written to `nixos/core/network/user-configs/network-config.nix` (actual file)
- `flake.nix` loads directly from `user-configs/` (not from symlink)
- **CRITICAL**: Use `config.core.system-manager.api.configHelpers.setupConfigFile` - NO manual Bash!

### 6.3 Versioning
- Define `_version = "1.0"` in `options.nix`
- On breaking changes: Increase version + create migration

### 6.4 Core vs. Feature Module
- Network is **Core Module** (`nixos/core/network/`)
- Options under `options.systemConfig.network`
- Enabled by default (`enable = true` default)
- Config in `user-configs/network-config.nix`

### 6.5 System-Manager API Usage
**CRITICAL**: Always use System-Manager API for config file management:
```nix
# ✅ CORRECT - Use System-Manager API
configHelpers = config.core.system-manager.api.configHelpers;
system.activationScripts.network-config-symlink = 
  configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;

# ❌ WRONG - NO direct Bash/Nix mixing
system.activationScripts.network-config-symlink = ''
  mkdir -p "$(dirname "${symlinkPath}")"
  ln -sfn "${userConfigFile}" "${symlinkPath}"
'';
```

**Why**: System-Manager API handles:
- Default config creation (only if missing)
- Symlink management (with backup on update)
- User config protection (won't overwrite existing configs)
- Proper error handling

---

## 7. Open Questions / TODOs

1. **`timeZone`**: Should go to `localization` module or stay in Network?
   - **Recommendation**: To `localization`, but Network can use fallback

2. **`hostName`**: Stay in Network or move to separate module?
   - **Recommendation**: Stay in Network (network-relevant)

3. **Firewall Services**: Should services be in separate config file?
   - **Recommendation**: No, stays in `network.firewall.services`

---

## 8. Next Steps

1. **Immediately**: Create/refactor files (Phase 2-3) - **USE SYSTEM-MANAGER API!**
2. **Then**: Fix config migration (Phase 4)
3. **After**: Testing (Phase 5)
4. **Finally**: Complete documentation

---

**Created**: 2025-01-XX
**Status**: 📋 Plan created, waiting for implementation
**Responsible**: Development Team

**CRITICAL REMINDER**: 
- ✅ Always use `config.core.system-manager.api.configHelpers`
- ✅ Use absolute paths: `/etc/nixos/core/network/user-configs/network-config.nix`
- ✅ Use `configHelpers.setupConfigFile` for symlink management
- ❌ NO direct Bash/Nix syntax mixing
- ❌ NO manual `mkdir -p` or `ln -sfn` in activation scripts

