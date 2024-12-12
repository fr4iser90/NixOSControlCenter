# modules/desktop/display/x11/extensions.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    glxinfo         # OpenGL information
    libGL           # OpenGL library
    mesa            # OpenGL implementation
    libvdpau        # Video acceleration
    libva           # Video acceleration API
  ];
}