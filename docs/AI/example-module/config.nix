{ config, lib, pkgs, systemConfig, getModuleConfigFromPath, getCurrentModuleMetadata, configHelpers, ... }:

let
  # Get module metadata (generic, not hardcoded)
  moduleConfig = getCurrentModuleMetadata ./.;
  moduleName = moduleConfig.name;
  # Get config with defaults from options.nix and template-config.nix
  cfg = getModuleConfigFromPath moduleConfig.configPath;
  defaultConfig = builtins.readFile ./template-config.nix;
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or false) (
      (configHelpers.createModuleConfig {
        inherit moduleName;
        defaultConfig = defaultConfig;
      }) // {
        environment.systemPackages = with pkgs; [
          # Add your packages here
        ];

        assertions = [
          {
            assertion = cfg.option2 > 0;
            message = "option2 must be greater than 0";
          }
        ];
      }
    ))
  ];
}

