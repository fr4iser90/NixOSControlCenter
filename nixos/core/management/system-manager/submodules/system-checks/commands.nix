{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, moduleName, corePathsLib, ... }:

let
  cfg = getModuleConfig moduleName;
  prebuildCfg = cfg.prebuild or {};
  postbuildScript = import ./scripts/postbuild-checks.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  prebuildCheckScript = import ./scripts/prebuild-checks.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
in {
  config = lib.mkMerge [
    # Command-Center registration for checks module
    # CLI-Registry Pfad zentralisiert über corePathsLib
    (lib.setAttrByPath corePathsLib.getCliRegistryCommandsPathList [
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
    ])
  ];
}
