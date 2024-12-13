# modules/profiles/types/server/headless.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../../env.nix;
in {
  config = lib.mkIf (env.systemType == "headless") {
    # Server-spezifische Konfiguration
    services.openssh.enable = env.overrides.enableSSH or false;
    networking.firewall.enable = env.overrides.enableFirewall or true;
    # ... weitere Server-Einstellungen
  };
}