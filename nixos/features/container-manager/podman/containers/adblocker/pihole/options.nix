{ lib, ... }:

with lib;

{
  options.services.pihole = {
    enable = mkEnableOption "Pi-hole network-wide ad blocker";

    subdomain = mkOption {
      type = types.str;
      description = "Subdomain for Pi-hole web interface";
    };

    domain = mkOption {
      type = types.str;
      description = "Base domain for Pi-hole service";
    };

    webPassword = mkOption {
      type = types.str;
      description = "Password for Pi-hole web interface";
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = [ "1.1.1.1" "1.0.0.1" ];
      description = "Upstream DNS servers";
    };

    imageTag = mkOption {
      type = types.str;
      default = "latest";
      description = "Pi-hole container image tag";
    };

    resourceLimits = {
      cpu = mkOption {
        type = types.str;
        default = "0.5";
        description = "CPU limit (in cores)";
      };

      memory = mkOption {
        type = types.str;
        default = "512m";
        description = "Memory limit";
      };

      swap = mkOption {
        type = types.str;
        default = "512m";
        description = "Swap limit";
      };
    };
  };
}
