# modules/profiles/hybrid/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [ 
    ./gaming-workstation.nix  # Importiere das Profil direkt
  ];
  services.dbus.enable = true;
}