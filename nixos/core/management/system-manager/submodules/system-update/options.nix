{ config, lib, systemConfig, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.core.management.system-manager.submodules.system-update = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module version";
    };

    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable system update functionality";
    };

    autoBuild = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically build system after update";
    };

    backup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable backup before system updates";
      };

      retention = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "Number of backup generations to keep";
      };

      directory = lib.mkOption {
        type = lib.types.str;
        default = "/var/backup/nixos";
        description = "Directory to store system backups";
      };
    };

    sources = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name of the update source";
          };
          url = lib.mkOption {
            type = lib.types.str;
            description = "URL or path to the NixOS configuration";
          };
          branches = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Available branches for this source";
          };
        };
      });
      default = [
        {
          name = "remote";
          url = "https://github.com/fr4iser90/NixOSControlCenter.git";
          branches = [ "main" "develop" "experimental" ];
        }
        {
          name = "local";
          url = "/home/${systemConfig.core.base.user.${builtins.head (builtins.attrNames systemConfig.core.base.user or {})}.name or "user"}/Documents/Git/NixOSControlCenter/nixos";
          branches = [];
        }
      ];
      description = "Update sources for the system";
    };
  };
}
