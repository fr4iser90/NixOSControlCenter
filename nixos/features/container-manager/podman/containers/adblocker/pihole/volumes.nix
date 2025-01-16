{ config, lib, pkgs, ... }:

with lib;

let
  piholeUser = config.containerManager.user;
  piholeDataDir = "${config.users.users.${piholeUser}.home}/.local/share/containers/pihole";
in {
  containerManager.containers.pihole = {
    volumes = {
      "${piholeDataDir}/etc-pihole" = {
        containerPath = "/etc/pihole";
        mode = "rw";
      };
      "${piholeDataDir}/etc-dnsmasq.d" = {
        containerPath = "/etc/dnsmasq.d";
        mode = "rw";
      };
      "${piholeDataDir}/logs" = {
        containerPath = "/var/log";
        mode = "rw";
      };
    };
  };

  system.activationScripts.pihole-volumes = ''
    mkdir -p ${piholeDataDir}/{etc-pihole,etc-dnsmasq.d,logs}
    chown -R ${piholeUser}:${piholeUser} ${piholeDataDir}
    chmod 755 ${piholeDataDir}
  '';
}
