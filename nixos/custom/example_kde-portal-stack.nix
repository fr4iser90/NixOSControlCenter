# Example: KDE Plasma (Wayland) — xdg-desktop-portal stack for screen share, file dialogs, etc.
# nixos/custom/default.nix skips example_*.nix — import explicitly, e.g.:
#   imports = [ ./custom/example_kde-portal-stack.nix ];
#
# Requires a working Plasma session; PipeWire should be enabled for ScreenCast (typical on Plasma).
{ config, lib, pkgs, ... }:

{
  xdg.portal.enable = true;
  # Top-level pkgs.xdg-desktop-portal-kde is gone in current nixpkgs; use kdePackages (Plasma 6 / Qt6).
  xdg.portal.extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];

  xdg.portal.config = {
    common.default = [ "kde" ];
    kde = {
      default = [ "kde" ];
      "org.freedesktop.impl.portal.Secret" = [ "kde" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "kde" ];
    };
  };
}
