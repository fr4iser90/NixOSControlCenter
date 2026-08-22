{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "NixOS Control Center module version";
    };

    # NOTE: No enable option - nixos-control-center is always active (Core module)

    # NCC API Option (GENERISCH unter configPath.api!)
    api = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      description = "NCC API for other modules";
    };

    # Host policy: skip cli-registry “dangerous command” yes/no for all marked cmds.
    # Per-run: --yes / -y / --auto, or env NCC_ASSUME_YES=1.
    # Does NOT imply system-manager.autoBuild (build+switch is separate).
    dangerousIgnore = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Skip dangerous-command confirmation prompts (cli-registry).
        For unattended hosts / scripting. Prefer per-run `--yes` when possible.
        Rebuild after changing systemConfig. Pair with system-manager.autoBuild
        only if updates should also build+switch without a second prompt.
      '';
      example = true;
    };

    # NCC-spezifische Optionen können hier hinzugefügt werden
    # theme = lib.mkOption {
    #   type = lib.types.enum [ "dark" "light" ];
    #   default = "dark";
    #   description = "Theme for NCC CLI output";
    # };
  };
}
