{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  networkCfg = getModuleConfig "network";
  wifiCfg = networkCfg.wifi or { };
  headlessWifi = wifiCfg.preserveSystemConnections or true;
in
{
  networking = {
    useDHCP = false;
    useNetworkd = false;

    networkmanager = {
      enable = true;
      wifi.powersave = systemConfig.enablePowersave or false;
      # Random MAC forces a full scan before connect; breaks fast headless autoconnect.
      wifi.scanRandMacAddress = !headlessWifi;
      dns = lib.attrByPath ["networkManager" "dns"] "default" networkCfg;
    };
  };
}
