# modules/profiles/desktop/default.nix
{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./gaming.nix  # Importiere das Profil direkt
  ];

}