# modules/networking/networkmanager.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;
  isGnome = env.desktop == "gnome";
  isPlasma = env.desktop == "plasma";
in {
  # NetworkManager Konfiguration
  networking = {
    # Deaktiviere andere Network-Manager
    useDHCP = false;
    useNetworkd = false;

    networkmanager = {
      enable = true;
      
      # Grundeinstellungen
      wifi = {
        powersave = env.enablePowersave or false;
        scanRandMacAddress = true;  # Privacy feature
      };

      # DNS-Einstellungen
      dns = env.networkManager.dns or "default"; # "default", "dnsmasq", "unbound"

      # Nur echte NM-Plugins
      plugins = with pkgs; [
        networkmanager-openvpn
        networkmanager-vpnc
        networkmanager-openconnect
      ];
    };
  };

  # Desktop-spezifische Pakete
  environment.systemPackages = with pkgs; 
    [ networkmanager ]  # Basis-Tools
    ++ lib.optional isPlasma plasma-nm
    ++ lib.optional isGnome networkmanager-gnome
    ++ lib.optional (config.services.xserver.enable && !isGnome) networkmanagerapplet;

  # Systemd-Integration
  systemd.services.NetworkManager = {
    enable = true;
    wantedBy = [ "network.target" ];
  };
}