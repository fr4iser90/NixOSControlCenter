{ lib, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath or "systemConfig.core.management.system-manager.submodules.system-checks";  # Fallback

  # Default postbuild checks (moved from postbuild/default.nix)
  defaultPostbuildChecks = {
    passwords = {
      enable = true;
      description = "Check admin user passwords";
    };

    filesystem = {
      enable = true;
      description = "Check filesystem permissions and directories";
    };

    services = {
      enable = true;
      description = "Check critical system services";
    };
  };

  # Default prebuild checks
  defaultPrebuildChecks = {
    cpu = {
      enable = true;
      description = "Check CPU configuration";
    };

    gpu = {
      enable = true;
      description = "Check GPU configuration";
    };

    memory = {
      enable = true;
      description = "Check memory configuration";
    };

    users = {
      enable = true;
      description = "Check user configuration";
    };
  };

in {
  options.${configPath} = {
    # Version metadata (REQUIRED for all modules)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Module version";
    };

    # For management modules, enable is usually true by default
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable system checks and validation";
    };

    # Postbuild checks configuration
    postbuild = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable postbuild checks after system activation";
      };

      checks = lib.mkOption {
        type = lib.types.submodule {
          options = lib.mapAttrs (name: check: {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = check.enable;
              description = check.description;
            };
          }) defaultPostbuildChecks;
        };
        default = {};
        description = "Postbuild check configuration";
      };
    };

    # Prebuild checks configuration
    prebuild = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable prebuild checks before system build";
      };

      checks = lib.mkOption {
        type = lib.types.submodule {
          options = lib.mapAttrs (name: check: {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = check.enable;
              description = check.description;
            };
          }) defaultPrebuildChecks;
        };
        default = {};
        description = "Prebuild check configuration";
      };
    };
  };
}

