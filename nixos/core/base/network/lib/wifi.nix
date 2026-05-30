# Helpers for declarative and persisted WiFi profiles
{ lib, ... }:

let
  inherit (lib) optionalAttrs;

  buildEnsureProfiles = networks:
    lib.mapAttrs' (name: net: {
      name = name;
      value = {
        connection = {
          id = name;
          type = "wifi";
          autoconnect = net.autoconnect or true;
        } // optionalAttrs ((net.priority or 0) != 0) {
          autoconnect-priority = net.priority;
        };

        wifi = {
          mode = "infrastructure";
          ssid = net.ssid or name;
        };

        wifi-security =
          if (net.psk or null) != null then {
            auth-alg = "open";
            key-mgmt = "wpa-psk";
            psk = net.psk;
          } else if (net.pskFile or null) != null then {
            auth-alg = "open";
            key-mgmt = "wpa-psk";
            psk-file = net.pskFile;
          } else { };
      };
    }) networks;
in
{
  inherit buildEnsureProfiles;
}
