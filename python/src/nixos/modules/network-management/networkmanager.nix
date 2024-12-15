# nixconfig/networking/networkmanager.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;
in {
  networking = {
    useDHCP = false;
    useNetworkd = false;

    networkmanager = {
      enable = true;
      wifi.powersave = env.enablePowersave or false;
      wifi.scanRandMacAddress = true;
      dns = env.networkManager.dns or "default";
    };
  };

  # Desktop Integration wenn Desktop vorhanden
  programs.nm-applet.enable = env.desktop != null;
}