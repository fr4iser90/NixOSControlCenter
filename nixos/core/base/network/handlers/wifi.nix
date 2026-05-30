{ config, lib, pkgs, getModuleConfig, ... }:

let
  cfg = getModuleConfig "network";
  wifiCfg = cfg.wifi or { };

  wifiEnabled = wifiCfg.enable or true;
  preserveProfiles = wifiCfg.preserveSystemConnections or true;
  configNetworks = wifiCfg.networks or { };

  secretsWifiDir = "/etc/nixos/secrets/wifi";

  secretNetworks = import ../lib/wifi-secrets.nix {
    inherit lib;
    secretsPath = secretsWifiDir;
  };

  mergedNetworks = lib.recursiveUpdate secretNetworks configNetworks;

  hasPsk = net:
    (net.psk or null) != null || (net.pskFile or null) != null;

  networksWithPsk = lib.filterAttrs (_: net: hasPsk net) mergedNetworks;

  hasEnsureWifi = wifiEnabled && networksWithPsk != { };

  wifiLib = import ../lib/wifi.nix { inherit lib; };
  ensureProfiles = wifiLib.buildEnsureProfiles networksWithPsk;

  persistDir = "/var/lib/nixos-control-center/networkmanager-connections";
  liveDir = "/etc/NetworkManager/system-connections";

  restoreScript = import ../lib/restore-wifi-script.nix {
    inherit pkgs persistDir liveDir secretsWifiDir;
  };

  restoreActive = wifiEnabled && preserveProfiles && !hasEnsureWifi;
in
{
  networking.networkmanager.ensureProfiles = lib.mkIf hasEnsureWifi ensureProfiles;

  systemd.services.ncc-restore-wifi-profiles = lib.mkIf restoreActive {
    description = "Restore WiFi profiles with embedded PSK before NetworkManager (headless)";
    wantedBy = [ "multi-user.target" ];
    before = [ "NetworkManager.service" "network-online.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = restoreScript;
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
