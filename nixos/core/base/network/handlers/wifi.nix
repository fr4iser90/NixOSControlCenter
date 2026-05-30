{ config, lib, pkgs, getModuleConfig, ... }:

let
  cfg = getModuleConfig "network";
  wifiCfg = cfg.wifi or { };

  wifiEnabled = wifiCfg.enable or true;
  preserveProfiles = wifiCfg.preserveSystemConnections or true;
  configNetworks = wifiCfg.networks or { };

  secretsWifiDir = "/etc/nixos/secrets/wifi";

  hasPsk = net:
    (net.psk or null) != null || (net.pskFile or null) != null;

  # Only explicit wifi.networks in config → ensureProfiles.
  # /etc/nixos/secrets/wifi/*.psk (from ncc wifi connect) → restore at boot (embedded PSK, headless).
  configNetworksWithPsk = lib.filterAttrs (_: net: hasPsk net) configNetworks;

  hasEnsureWifi = wifiEnabled && configNetworksWithPsk != { };

  wifiLib = import ../lib/wifi.nix { inherit lib; };
  ensureProfiles = wifiLib.buildEnsureProfiles configNetworksWithPsk;

  persistDir = "/var/lib/nixos-control-center/networkmanager-connections";
  liveDir = "/etc/NetworkManager/system-connections";

  restoreScript = import ../lib/restore-wifi-script.nix {
    inherit pkgs persistDir liveDir secretsWifiDir;
  };

  autoconnectScript = import ../lib/wifi-autoconnect-script.nix {
    inherit pkgs persistDir liveDir secretsWifiDir;
  };

  restoreActive = wifiEnabled && preserveProfiles && !hasEnsureWifi;
  autoconnectActive = wifiEnabled && preserveProfiles;
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

  systemd.services.ncc-wifi-autoconnect = lib.mkIf autoconnectActive {
    description = "Activate saved WiFi profiles after NetworkManager (headless, no login)";
    wantedBy = [ "multi-user.target" ];
    after = [ "NetworkManager.service" "ncc-restore-wifi-profiles.service" ];
    before = [ "network-online.target" ];
    requires = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = autoconnectScript;
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
