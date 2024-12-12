# modules/profiles/desktop/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./gaming.nix  # Importiere das Profil direkt
  ];

  # Basis-Konfiguration für Desktop-Profile
  services = {
    xserver.enable = true;
    pipewire = {
      enable = true;
      pulse.enable = true;
    };
  };
}