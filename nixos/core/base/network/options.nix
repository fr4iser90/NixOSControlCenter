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

    # Networking services configuration (for firewall rules)
    networking = {
      services = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Service configurations for firewall rules";
      };

      firewall = {
        trustedNetworks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "List of trusted networks (CIDR notation)";
        };
      };
    };
  };
}
