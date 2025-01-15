{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.pihole;
in {
  options.services.pihole = {
    subdomain = mkOption {
      type = types.str;
      default = "pihole";
      description = ''
        Subdomain for Pi-hole web interface.
        Must be a valid DNS subdomain (alphanumeric and hyphens only).
      '';
    };

    domain = mkOption {
      type = types.str;
      default = "example.com";
      description = ''
        Base domain for the Pi-hole service.
        Must be a valid domain name (e.g., example.com).
      '';
    };

    imageTag = mkOption {
      type = types.str;
      default = "latest";
      description = "Docker image tag/version for Pi-hole";
    };

    security = {
      secrets = {
        webpassword = {
          source = mkOption {
            type = types.str;
            default = "/etc/nixos/secrets/pihole-webpassword";
            description = ''
              Path to file containing the web interface password.
              File should contain a single line with the password.
            '';
          };
        };
      };
    };

    monitoring = {
      enable = mkEnableOption "Enable monitoring for Pi-hole";
      interval = mkOption {
        type = types.str;
        default = "30s";
        description = "Health check interval for Pi-hole monitoring";
      };
    };

    imports = mkOption {
      type = types.listOf types.path;
      default = [];
      description = ''
        List of paths to import additional configurations.
        These will be merged with the base configuration.
      '';
    };
  };
}
