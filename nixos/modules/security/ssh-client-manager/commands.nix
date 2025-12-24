{ config, lib, pkgs, systemConfig, corePathsLib, ... }:

with lib;

let
  cfg = systemConfig.modules.security.ssh-client-manager;
in {
  config = mkIf cfg.enable
    (lib.mkMerge [
      (lib.setAttrByPath corePathsLib.getCliRegistryCommandsPathList [
      {
        name = "ssh-client-manager";
        description = "Manage SSH client connections";
        category = "network";
        script = "${config.modules.security.ssh-client-manager.sshClientManagerScript}/bin/ncc-ssh-client-manager-main";
        arguments = [];
        dependencies = [ "openssh" "fzf" "sshpass" ];
        shortHelp = "ssh-client-manager - Manage SSH client connections";
        longHelp = ''
          Interactive SSH client manager for managing SSH connections and keys.
          Provides a user-friendly interface for connecting to SSH servers,
          managing SSH keys, and configuring connection settings.
        '';
      }
      ])
    ]);
}
