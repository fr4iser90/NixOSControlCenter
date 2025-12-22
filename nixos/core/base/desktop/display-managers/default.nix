# display-managers/default.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Find user with autoLogin enabled
  # Returns null if no user has autoLogin set to true
  userCfg = getModuleConfig "user";
  autoLoginUser = lib.findFirst
    (user: userCfg.${user}.autoLogin or false)
    null
    (builtins.attrNames userCfg);

  desktopCfg = getModuleConfig "desktop";
in {
  # Import selected display manager configuration
  # Path is determined by systemConfig.core.base.desktop.display.manager
  imports = [
    (./. + "/${desktopCfg.display.manager}")
  ];

  # Configure auto-login if a user has it enabled
  # Only active when an autoLogin user is found
  services.displayManager.autoLogin = lib.mkIf desktopCfg.enable {
    enable = autoLoginUser != null;
    user = autoLoginUser;
  };

  # Verify display manager exists
  # Prevents configuration errors before build
  assertions = lib.mkIf desktopCfg.enable [{
    assertion = builtins.pathExists (./. + "/${desktopCfg.display.manager}");
    message = "Invalid display manager: ${desktopCfg.display.manager}";
  }];
}