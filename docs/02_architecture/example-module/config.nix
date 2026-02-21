{ config, lib, pkgs, systemConfig, getModuleConfigFromPath, getCurrentModuleMetadata, configHelpers, ... }:

let
  # Get module metadata (generic, not hardcoded)
  moduleConfig = getCurrentModuleMetadata ./.;
  # Get config with defaults from options.nix and template-config.nix
  # This ensures template defaults are always available
  cfg = getModuleConfigFromPath moduleConfig.configPath;
  # Use the template file as default config
  # configHelpers is available via _module.args (no import needed!)
  defaultConfig = builtins.readFile ./template-config.nix;
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or false) (
      (configHelpers.createModuleConfig {
        moduleName = "example-module";
        defaultConfig = defaultConfig;
      }) // {
        # Module implementation (only when enabled)
        # Use cfg for user settings (includes template defaults)
        
        # Example: Add system packages
        environment.systemPackages = with pkgs; [
          # Add your packages here
        ];

        # Example: Configure services
        # services.example-service = {
        #   enable = true;
        #   config = cfg.option1;
        # };

        # Example: Assertions
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

