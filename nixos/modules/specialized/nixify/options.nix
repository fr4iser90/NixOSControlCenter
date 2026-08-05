{ config, lib, pkgs, ... }:

let
  moduleVersion = "0.1.0";
in
{
  options.systemConfig.modules.specialized.nixify = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module version";
    };

    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Nixify - Windows/macOS/Linux → NixOS System-DNA-Extractor";
    };

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

          showStatusBadge = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Show Active/Disabled status badges for modules in the web interface";
          };
        };
      };
      default = {};
      description = "Web service configuration";
    };

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

    # Mapping DB lives as Nix under ./data/*.nix — not a user-facing path option

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
            description = "Directory for generated ISO images";
          };
        };
      };
      default = {};
      description = "ISO builder configuration";
    };
  };
}
