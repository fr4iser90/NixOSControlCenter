# modules/desktop/display/x11/extensions.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    mesa-demos         # OpenGL information
    libGL           # OpenGL library
    mesa            # OpenGL implementation
    libvdpau        # Video acceleration
    libva           # Video acceleration API
    xrdb       # X resources database
    xrandr     # Screen management
    xsetroot   # Root window settings
    xmodmap    # Keyboard mapping
    xset       # User preferences
  ];
}