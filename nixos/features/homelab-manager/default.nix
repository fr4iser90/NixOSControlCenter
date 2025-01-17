{ config, lib, pkgs, systemConfig, ... }:

let
  # Finde alle Benutzer mit virtualization Rolle
  virtUsers = lib.filterAttrs 
    (name: user: user.role == "virtualization") 
    systemConfig.users;

  # Prüfe ob wir Virtualisierungsbenutzer haben
  hasVirtUsers = (lib.length (lib.attrNames virtUsers)) > 0;

  # Hole den ersten Virtualisierungsbenutzer, falls vorhanden
  virtUser = lib.head (lib.attrNames virtUsers);

in {


  imports = if hasVirtUsers then [
    ./homelab-create.nix
    ./homelab-fetch.nix
    # ./homelab-update.nix
    # ./homelab-delete.nix
    # ./homelab-status.nix
  ] else [];
}
