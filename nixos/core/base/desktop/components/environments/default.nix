# environments/default.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  desktopCfg = getModuleConfig "desktop";
  environment = desktopCfg.environment;
in {
  # Only import desktop environment if desktop is enabled
  # Uses the environment specified in systemConfig.core.base.desktop.environment
  imports = [
    (./. + "/${environment}")  # Automatically loads the correct desktop environment
  ];

  # Verify that the specified desktop environment exists
  # This prevents configuration errors before the system build starts
  assertions = lib.mkIf desktopCfg.enable [{
    assertion = builtins.pathExists (./. + "/${environment}");
    message = "Desktop environment ${environment} not found in ${toString ./.}";
  }];
}