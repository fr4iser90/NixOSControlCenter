{ lib, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Packages module version";
    };

    # Feature sets / package modules (gaming, docker, web-dev, …)
    packageModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of package sets to enable (docker, gaming, web-dev, etc.). User-specific packages live under users.<name>.userPackages — not here.";
    };

    # System-wide individual packages
    systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "System-wide packages (installed for all users)";
    };

    # Preset configuration
    preset = {
      modules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Modules from preset configuration";
      };
    };

    # Docker configuration
    docker = {
      enable = lib.mkEnableOption "Docker support";
      root = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Docker privilege mode override.
          null = smart (rootless by default; root when Homelab Swarm or AI-Workspace is active).
          true = force root Docker; false = force rootless.
        '';
      };
    };
  };
}

