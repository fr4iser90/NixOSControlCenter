{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.core.management.module-manager or {};
  configHelpers = import ./lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./module-manager-config.nix;
in
{
  config = lib.mkMerge [
    # 🎯 CENTRAL REGISTRY: Module-Manager provides paths and APIs for other modules
    # This must be defined early so all modules can use it
    {
      _module.args.modulePaths = {
        configHelpers = ./lib/config-helpers.nix;
        backupHelpers = ../system-manager/lib/backup-helpers.nix;
        cliApi = ../../infrastructure/cli-formatter/lib;
        # CLI formatter API for modules that need it early
        cliFormatterApi = (import ../../infrastructure/cli-formatter/config.nix {
          inherit config lib pkgs systemConfig;
        }).apiValue;
      };

      # Also export via config for modules that load later
      core.management.module-manager.configHelpers = configHelpers;
    }

    (lib.mkIf (cfg.enable or true)
      (configHelpers.createModuleConfig {
        moduleName = "module-manager";
        defaultConfig = defaultConfig;
      })
    )
    # Module-manager is a core module that dynamically discovers all available modules
    # No additional system configuration needed - works dynamically
  ];
}