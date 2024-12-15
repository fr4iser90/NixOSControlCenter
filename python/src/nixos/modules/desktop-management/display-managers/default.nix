# display-managers/default.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  # Auto-Login Benutzer finden
  autoLoginUser = lib.findFirst 
    (user: systemConfig.users.${user}.autoLogin or false) 
    null 
    (builtins.attrNames systemConfig.users);
in {
  imports = [
    (./. + "/${systemConfig.displayManager}")  # Lädt automatisch den richtigen Display Manager
  ];

  # Nur Auto-Login Konfiguration
  services.displayManager.autoLogin = {
    enable = autoLoginUser != null;
    user = autoLoginUser;
  };
  assertions = [
    {
      assertion = builtins.pathExists (./. + "/${systemConfig.displayManager}");
      message = "Invalid display manager: ${systemConfig.displayManager}";
    }
  ];
}