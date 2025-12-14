{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.features.security.ssh-client-manager;
in {
  config = mkIf cfg.enable {
    core.management.system-manager.submodules.cli-registry.commands = [
      {
        name = "ssh-client-manager";
        description = "Manage SSH client connections";
        category = "network";
        script = "${config.features.security.ssh-client-manager.sshClientManagerScript}/bin/ncc-ssh-client-manager-main";
        arguments = [];
        dependencies = [ "openssh" "fzf" "sshpass" ];
        shortHelp = "ssh-client-manager - Manage SSH client connections";
        longHelp = ''
          Interactive SSH client manager for managing SSH connections and keys.
          Provides a user-friendly interface for connecting to SSH servers,
          managing SSH keys, and configuring connection settings.
        '';
      }
    ];
  };
}
