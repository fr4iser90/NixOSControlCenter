# modules/profiles/server/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./headless.nix  # Importiere das Profil direkt
  ];

  # Basis-Konfiguration für Server-Profile
  services = {
    openssh.enable = true;
  };
}