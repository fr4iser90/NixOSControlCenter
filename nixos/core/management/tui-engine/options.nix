{ lib, ... }:

{
  options.core.management.tui-engine = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "TUI engine module version";
    };

    enable = lib.mkEnableOption "TUI engine";

    buildGoApplication = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "buildGoApplication function for Go builds";
    };

    gomod2nix = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "gomod2nix package for Go module management";
    };

    pkgs = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "pkgs for accessing Nix packages";
    };

    tuiBinary = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "Built tui-engine binary";
    };

    tuiEngineSrc = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "TUI engine source with merged TUI files from all modules";
    };

    createTuiScript = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "Generic TUI script builder";
    };

    createTuiBinary = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "Function to build module-specific TUI binaries";
    };

    domainTui = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "Domain TUI helpers";
    };

    writeScriptBin = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "writeScriptBin function for creating scripts";
    };

    installShellFiles = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "installShellFiles package";
    };

    api = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      description = "TUI engine API for other modules";
    };

    moduleManagerTuiScript = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      description = "Module manager TUI script";
    };
  };
}
