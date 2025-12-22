# nixconfig/networking/networkmanager.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
{
  networking = {
    useDHCP = false;
    useNetworkd = false;

    networkmanager = {
      enable = true;
      wifi.powersave = systemConfig.enablePowersave or false;
      wifi.scanRandMacAddress = true;
      dns = lib.attrByPath ["networkManager" "dns"] "default" (getModuleConfig "network");
    };
  };
}