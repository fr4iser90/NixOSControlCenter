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
      dns = systemConfig.core.base.network.networkManager.dns or "default";
    };
  };
}