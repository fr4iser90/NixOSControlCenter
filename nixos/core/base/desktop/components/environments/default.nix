# environments/default.nix
{ config, lib, pkgs, systemConfig, ... }:
let
  desktopCfg = lib.attrByPath ["core" "base" "desktop"] {} systemConfig;
  environment = desktopCfg.environment or "plasma";
in {
  # Only import desktop environment if desktop is enabled
  # Uses the environment specified in systemConfig.core.base.desktop.environment
  imports = [
    (./. + "/${environment}")  # Automatically loads the correct desktop environment
  ];

  # Verify that the specified desktop environment exists
  # This prevents configuration errors before the system build starts
  assertions = lib.mkIf (desktopCfg.enable or true) [{
    assertion = builtins.pathExists (./. + "/${environment}");
    message = "Desktop environment ${environment} not found in ${toString ./.}";
  }];
}