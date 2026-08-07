{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  # User-facing options — live under systemConfig.${configPath}
  # (e.g. systemConfig.core.management.tui-engine). Move-safe via discovery.
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "TUI engine module version";
    };

    enable = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Build and register NCC Bubble Tea TUIs.

        - null (default): auto — disabled when desktop is enabled, enabled on headless
        - true / false: explicit override in systemConfig

        Example (systemConfig):
          core.management.tui-engine.enable = true;
      '';
    };

    # Internal builder plumbing (not for hand-editing in systemConfig)
    buildGoApplication = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "buildGoApplication function for Go builds";
    };

    gomod2nix = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "gomod2nix package";
    };

    pkgs = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "pkgs";
    };

    tuiBinary = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      default = null;
      description = "Built tui-engine binary";
    };

    tuiEngineSrc = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      default = null;
      description = "TUI engine source";
    };

    createTuiScript = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      default = null;
      description = "Generic TUI script builder";
    };

    createTuiBinary = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      default = null;
      description = "Module-specific TUI binary builder";
    };

    domainTui = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      default = null;
      description = "Domain TUI helpers";
    };

    writeScriptBin = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      default = null;
      description = "writeScriptBin";
    };

    installShellFiles = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      default = null;
      description = "installShellFiles";
    };

    api = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      default = {};
      description = "TUI engine API";
    };

    moduleManagerTuiScript = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      internal = true;
      description = "Module manager TUI script (null when TUI disabled)";
    };
  };
}
