# modules/desktop/managers/desktop/plasma.nix
{ config, pkgs, systemConfig, ... }: {
  # Plasma 6 Basis
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";
  programs.kdeconnect.enable = true;

  # Wayland Support
  programs.xwayland.enable = true;

  # Alte Plasma 5 Pakete entfernen
  environment.plasma5.excludePackages = [ "*" ];

  # Notwendige Services
  services.dbus.enable = true;
  
  environment.sessionVariables = {
    TERMINAL = "kitty";
    DEFAULT_TERMINAL = "kitty";
    
    # Gaming Optimierungen
    SDL_VIDEODRIVER = "wayland,x11";  # Kein x11 fallback
  };
}
