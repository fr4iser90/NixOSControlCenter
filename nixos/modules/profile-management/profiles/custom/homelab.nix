{ config, lib, pkgs, ... }:

{


  # Basis-Konfiguration für Homelab
  services.openssh.enable = true;
  virtualisation.docker.enable = true;
  
  # Optional GUI
  services.xserver.enable = lib.mkDefault true;
  
  # Netzwerk-Konfiguration
  networking = {
    firewall.enable = true;
    networkmanager.enable = true;
  };
}