# This module adds the calamares installer to the basic graphical NixOS
# installation CD.

{ pkgs, ... }:
let
  calamares-nixos-autostart = pkgs.makeAutostartItem {
    name = "calamares";
    package = pkgs.calamares-nixos;
  };
in
{
  imports = [ ./installation-cd-graphical-base.nix ];

  # required for kpmcore to work correctly
  programs.partition-manager.enable = true;

  environment.systemPackages = [
    # Calamares for graphical installation
    pkgs.calamares-nixos
    calamares-nixos-autostart  # Local variable from let block
    pkgs.calamares-nixos-extensions  # CRITICAL: Explicit pkgs. to ensure overlay is applied
    # Get list of locales
    pkgs.glibcLocales
  ];

  # Support choosing from any locale
  i18n.supportedLocales = [ "all" ];
}
