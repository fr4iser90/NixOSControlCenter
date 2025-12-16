# environments/default.nix
{ config, lib, pkgs, systemConfig, ... }:
{
  # Only import desktop environment if desktop is enabled
  # Uses the environment specified in systemConfig.system.desktop.environment
  imports = [
    (./. + "/${systemConfig.core.base.desktop.environment}")  # Automatically loads the correct desktop environment
  ];

  # Verify that the specified desktop environment exists
  # This prevents configuration errors before the system build starts
  assertions = lib.mkIf systemConfig.core.base.desktop.enable [{
    assertion = builtins.pathExists (./. + "/${systemConfig.core.base.desktop.environment}");
    message = "Desktop environment ${systemConfig.core.base.desktop.environment} not found in ${toString ./.}";
  }];
}