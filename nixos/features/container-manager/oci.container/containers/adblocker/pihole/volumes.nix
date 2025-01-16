{ lib, config, ... }:
with lib;

{
  # Only apply these volumes if pihole is enabled
  config = mkIf config.services.pihole.enable {
    storage.volumes = {
      "pihole/etc-pihole" = {
        path = "${config.storage.baseDir}/pihole/etc-pihole";
        user = "pihole";
        group = "pihole";
        mode = "755";
        backup = true;
        initData = builtins.toPath ./data/etc-pihole;
      };

      "pihole/etc-dnsmasq.d" = {
        path = "${config.storage.baseDir}/pihole/etc-dnsmasq.d";
        user = "pihole";
        group = "pihole";
        mode = "755";
        backup = true;
        initData = builtins.toPath ./data/etc-dnsmasq.d;
      };
      
      "run/pihole" = {
        path = "/run/pihole";
        user = "pihole";
        group = "pihole";
        mode = "755";
        backup = false;
      };

      "var/log" = {
        path = "${config.storage.baseDir}/var/log";
        user = "pihole";
        group = "pihole";
        mode = "755";
        backup = false;
      };
    };
  };
}
