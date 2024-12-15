# modules/profiles/desktop/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./gaming.nix  # Importiere das Profil direkt
  ];

}