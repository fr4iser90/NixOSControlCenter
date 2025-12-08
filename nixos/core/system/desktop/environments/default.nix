# environments/default.nix
{ config, lib, pkgs, systemConfig, ... }:
{
  # Only import desktop environment if desktop is enabled
  # Uses the environment specified in systemConfig.system.desktop.environment
  imports = [
    (./. + "/${systemConfig.system.desktop.environment}")  # Automatically loads the correct desktop environment
  ];

  # Verify that the specified desktop environment exists
  # This prevents configuration errors before the system build starts
  assertions = lib.mkIf systemConfig.system.desktop.enable [{
    assertion = builtins.pathExists (./. + "/${systemConfig.system.desktop.environment}");
    message = "Desktop environment ${systemConfig.system.desktop.environment} not found in ${toString ./.}";
  }];
}