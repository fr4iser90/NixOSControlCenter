# modules/desktop/display/x11/extensions.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    mesa-demos         # OpenGL information
    libGL           # OpenGL library
    mesa            # OpenGL implementation
    libvdpau        # Video acceleration
    libva           # Video acceleration API
    xorg.xrdb       # X resources database
    xorg.xrandr     # Screen management
    xorg.xsetroot   # Root window settings
    xorg.xmodmap    # Keyboard mapping
    xorg.xset       # User preferences
  ];
}