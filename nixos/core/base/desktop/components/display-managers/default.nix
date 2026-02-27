{ config, lib, pkgs, systemConfig, ... }:

let
  desktopCfg = lib.attrByPath ["core" "base" "desktop"] {} systemConfig;
  userCfg = lib.attrByPath ["core" "base" "user"] {} systemConfig;
  autoLoginUser = lib.findFirst
    (user: userCfg.${user}.autoLogin or false)
    null
    (builtins.attrNames userCfg);
in {
  # Import selected display manager configuration
  # Path is determined by systemConfig.core.base.desktop.display.manager
  imports = [
    (./. + "/${desktopCfg.display.manager or "sddm"}")
  ];

  # Configure auto-login if a user has it enabled
  # Only active when an autoLogin user is found
  services.displayManager.autoLogin = lib.mkIf (desktopCfg.enable or true) {
    enable = autoLoginUser != null;
    user = autoLoginUser;
  };

  # Verify display manager exists
  # Prevents configuration errors before build
  assertions = lib.mkIf (desktopCfg.enable or true) [{
    assertion = builtins.pathExists (./. + "/${desktopCfg.display.manager or "sddm"}");
    message = "Invalid display manager: ${desktopCfg.display.manager or "sddm"}";
  }];
}