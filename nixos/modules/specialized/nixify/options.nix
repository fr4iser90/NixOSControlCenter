{ config, lib, pkgs, ... }:

let
  moduleVersion = "0.1.0";
in
{
  options.systemConfig.modules.specialized.nixify = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module version";
    };

    # Enable option for optional modules
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Nixify - Windows/macOS/Linux → NixOS System-DNA-Extractor";
    };

    # Web-Service configuration
    webService = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable web service for receiving snapshot reports";
          };
          
          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
            description = "Web service port";
          };
          
          host = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Web service host (0.0.0.0 for all interfaces, 127.0.0.1 for localhost only)";
          };
          
          autoStart = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Automatically start web service on boot";
          };
        };
      };
      default = {};
      description = "Web service configuration";
    };

    # Snapshot configuration
    snapshot = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable snapshot scripts (Windows/macOS/Linux)";
          };
        };
      };
      default = {};
      description = "Snapshot scripts configuration";
    };

    # Mapping database configuration
    mapping = lib.mkOption {
      type = lib.types.submodule {
        options = {
          databasePath = lib.mkOption {
            type = lib.types.path;
            default = ./mapping/mapping-database.json;
            description = "Path to mapping database JSON file";
          };
        };
      };
      default = {};
      description = "Mapping database configuration";
    };

    # ISO builder configuration
    isoBuilder = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable ISO builder for custom NixOS ISOs";
          };
          
          outputDir = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/nixify/isos";
            description = "Directory where built ISOs are stored";
          };
        };
      };
      default = {};
      description = "ISO builder configuration";
    };
  };
}
