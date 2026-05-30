{ lib, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Network module version";
    };

    # NetworkManager specific options
    networkManager = {
      dns = lib.mkOption {
        type = lib.types.str;
        default = "default";
        description = "DNS configuration for NetworkManager";
      };
    };

    # WiFi — declarative and/or persisted (works without desktop session)
    wifi = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable WiFi profile management. When true, system-wide profiles are
          preserved across rebuilds and restored before NetworkManager starts,
          so wireless works even with desktop disabled (no Plasma login required).
        '';
      };

      preserveSystemConnections = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Restore persisted WiFi profiles at boot (before NetworkManager).
          Use ncc wifi connect with the SSID to save passwords to
          /etc/nixos/secrets/wifi/ on the system.
        '';
      };

      networks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            ssid = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "WiFi SSID (defaults to the attribute name if empty)";
            };
            psk = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "WPA PSK (prefer pskFile for secrets)";
            };
            pskFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path to file containing WPA PSK";
            };
            autoconnect = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Connect automatically";
            };
            priority = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Autoconnect priority";
            };
          };
        });
        default = { };
        description = ''
          Declarative WiFi networks (networking.networkmanager.ensureProfiles).
          When non-empty, takes precedence over preserved GUI profiles.
        '';
        example = {
          MyHome = {
            ssid = "MyHome";
            pskFile = "/etc/nixos/secrets/wifi-psk";
            autoconnect = true;
          };
        };
      };
    };

    # Basic networking options
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "System hostname";
    };

    # Firewall configuration
    firewall = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable system firewall";
      };

      trustedNetworks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of trusted networks (CIDR notation)";
      };
    };

    # Networking services configuration (for firewall rules)
    services = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Service configurations for firewall rules";
    };
  };
}
