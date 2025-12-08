# display-managers/default.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  # Find user with autoLogin enabled
  # Returns null if no user has autoLogin set to true
  autoLoginUser = lib.findFirst 
    (user: systemConfig.users.${user}.autoLogin or false) 
    null 
    (builtins.attrNames (systemConfig.users or {}));
in {
  # Import selected display manager configuration
  # Path is determined by systemConfig.system.desktop.display.manager
  imports = [ 
    (./. + "/${systemConfig.system.desktop.display.manager}") 
  ];

  # Configure auto-login if a user has it enabled
  # Only active when an autoLogin user is found
  services.displayManager.autoLogin = lib.mkIf systemConfig.system.desktop.enable {
    enable = autoLoginUser != null;
    user = autoLoginUser;
  };

  # Verify display manager exists
  # Prevents configuration errors before build
  assertions = lib.mkIf systemConfig.system.desktop.enable [{
    assertion = builtins.pathExists (./. + "/${systemConfig.system.desktop.display.manager}");
    message = "Invalid display manager: ${systemConfig.system.desktop.display.manager}";
  }];
}