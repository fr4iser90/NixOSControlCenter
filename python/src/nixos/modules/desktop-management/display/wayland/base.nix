# modules/desktop/display/wayland/base.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    wayland
    wayland-protocols
    wayland-utils
    xwayland
  ];
  
  environment.sessionVariables = {
    # Wayland Basis
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
    
    # Qt/GTK mit Fallback
    QT_QPA_PLATFORM = "wayland;xcb";  # Fallback hinzugefügt
    GDK_BACKEND = "wayland,x11";      # Fallback hinzugefügt
  };

  security.polkit.enable = true;
  programs.dconf.enable = true;
  
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-kde ];
  };
}