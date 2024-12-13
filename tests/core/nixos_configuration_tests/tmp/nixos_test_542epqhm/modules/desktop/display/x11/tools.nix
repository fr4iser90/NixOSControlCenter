# modules/desktop/display/x11/tools.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    xorg.xrdb       # X resources database
    xorg.xrandr     # Screen management
    xorg.xsetroot   # Root window settings
    xorg.xmodmap    # Keyboard mapping
    xorg.xset       # User preferences
  ];
}