# nixconfig/networking/networkmanager.nix
{ config, lib, pkgs, systemConfig, ... }:
{
  networking = {
    useDHCP = false;
    useNetworkd = false;

    networkmanager = {
      enable = true;
      wifi.powersave = systemConfig.enablePowersave or false;
      wifi.scanRandMacAddress = true;
      dns = systemConfig.networkManager.dns or "default";
    };
  };

  # Desktop Integration wenn Desktop vorhanden
  programs.nm-applet.enable = systemConfig.desktop != null;
}