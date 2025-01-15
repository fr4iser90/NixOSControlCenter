{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.pihole;
in {
  options.services.pihole = {
    subdomain = mkOption {
      type = types.str;
      default = "pihole";
      description = "Subdomain for Pi-hole web interface";
    };

    domain = mkOption {
      type = types.str;
      default = "example.com";
      description = "Base domain for the pihole service";
    };

    security = {
      secrets = {
        webpassword = {
          source = mkOption {
            type = types.str;
            description = "Path to web password file";
          };
        };
      };
    };

    monitoring = {
      enable = mkEnableOption "Enable monitoring for Pi-hole";
    };

    imports = mkOption {
      type = types.listOf types.path;
      default = [];
      description = "List of paths to import additional configurations";
    };
  };

}
