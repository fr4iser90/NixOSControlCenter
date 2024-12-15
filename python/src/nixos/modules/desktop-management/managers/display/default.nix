# modules/desktop/display/default.nix
{ config, lib, pkgs, ... }:
let
  env = import ../../../../env.nix;
  
  # Auto-Login Benutzer finden
  autoLoginUser = lib.findFirst 
    (user: env.users.${user}.autoLogin or false) 
    null 
    (builtins.attrNames env.users);

  # Import des spezifischen Display Manager Moduls
  displayManagerModule =  ./managers + "/${env.displayManager}.nix";
in {
  imports = [ displayManagerModule ];


  # Gemeinsame Display Manager Konfiguration
#  services.displayManager = {
#    defaultSession = env.session;
    
    # Auto-Login wenn konfiguriert
#    autoLogin = lib.mkIf (autoLoginUser != null) {
#      enable = true;
#      user = autoLoginUser;
#    };
#  };

  assertions = [{
    assertion = lib.count (user: env.users.${user}.autoLogin or false) 
                        (builtins.attrNames env.users) <= 1;
    message = "Only one user can be configured for auto-login";
  }];
}