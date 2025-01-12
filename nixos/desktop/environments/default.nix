# environments/default.nix
{ config, lib, pkgs, systemConfig, ... }:
{
  # Only import desktop environment if desktop is enabled
  # Uses the environment specified in systemConfig.desktop.environment
  imports = [
    (./. + "/${systemConfig.desktop.environment}")  # Automatically loads the correct desktop environment
  ];

  # Verify that the specified desktop environment exists
  # This prevents configuration errors before the system build starts
  assertions = lib.mkIf systemConfig.desktop.enable [{
    assertion = builtins.pathExists (./. + "/${systemConfig.desktop.environment}");
    message = "Desktop environment ${systemConfig.desktop.environment} not found in ${toString ./.}";
  }];
}