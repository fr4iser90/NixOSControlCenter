# modules/profiles/types/server/headless.nix
{ config, lib, pkgs, systemConfig, ... }:

{
  config = lib.mkIf (systemConfig.systemType == "headless") {
    # Server-spezifische Konfiguration
    services.openssh.enable = systemConfig.overrides.enableSSH or false;
    networking.firewall.enable = systemConfig.overrides.enableFirewall or true;

  };
}