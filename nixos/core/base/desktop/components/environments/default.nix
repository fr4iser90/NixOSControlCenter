# environments/default.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "desktop";
  environment = cfg.environment or "plasma";
in {
  # Only import desktop environment if desktop is enabled
  # Uses desktop.environment from getModuleConfig
  imports = lib.optionals (cfg.enable or true) [
    (./. + "/${environment}")  # Automatically loads the correct desktop environment
  ];

  # Verify that the specified desktop environment exists
  # This prevents configuration errors before the system build starts
  assertions = lib.mkIf (cfg.enable or true) [{
    assertion = builtins.pathExists (./. + "/${environment}");
    message = "Desktop environment ${environment} not found in ${toString ./.}";
  }];
}