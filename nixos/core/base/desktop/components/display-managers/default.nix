{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "desktop";
  userCfg = getModuleConfig "user";
  autoLoginUser = lib.findFirst
    (user: userCfg.${user}.autoLogin or false)
    null
    (builtins.attrNames userCfg);
in {
  # Import selected display manager configuration
  # Path is determined by desktop.display.manager (getModuleConfig)
  imports = lib.optionals (cfg.enable or true) [
    (./. + "/${cfg.display.manager or "sddm"}")
  ];

  # Configure auto-login if a user has it enabled
  # Only active when an autoLogin user is found
  services.displayManager.autoLogin = lib.mkIf (cfg.enable or true) {
    enable = autoLoginUser != null;
    user = autoLoginUser;
  };

  # Verify display manager exists
  # Prevents configuration errors before build
  assertions = lib.mkIf (cfg.enable or true) [{
    assertion = builtins.pathExists (./. + "/${cfg.display.manager or "sddm"}");
    message = "Invalid display manager: ${cfg.display.manager or "sddm"}";
  }];
}