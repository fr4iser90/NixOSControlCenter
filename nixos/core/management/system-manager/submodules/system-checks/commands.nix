{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.core.management.system-manager.submodules.system-checks or {};
  prebuildCfg = cfg.prebuild or {};
  prebuildCheckScript = import ./scripts/prebuild-checks.nix { inherit config lib pkgs systemConfig; };
in {
  config = {
    # Command-Center registration for checks module
    core.management.system-manager.submodules.cli-registry.commands = [
      {
        name = "build";
        description = "Build and activate NixOS configuration with safety checks";
        category = "system";
        script = "${prebuildCheckScript}/bin/build";
        arguments = ["switch" "boot" "test" "build"];
        dependencies = [ "nix" ];
        shortHelp = "build <command> - Build with preflight checks";
        longHelp = ''
          Build and activate NixOS configuration with preflight safety checks

          Commands:
            switch    Build and activate configuration
            boot      Build boot configuration
            test      Test configuration
            build     Build only

          Options:
            --force   Skip safety checks
        '';
      }
    ];
  };
}
