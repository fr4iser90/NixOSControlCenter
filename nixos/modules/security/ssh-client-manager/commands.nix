{ config, lib, pkgs, systemConfig, getCurrentModuleMetadata, getModuleApi, ... }:

with lib;

let
  moduleConfig = getCurrentModuleMetadata ./.;
  cfg = systemConfig.${moduleConfig.configPath};
  cliRegistry = getModuleApi "cli-registry";
  moduleName = baseNameOf ./. ;
in {
  config = mkIf cfg.enable
    (lib.mkMerge [
      (cliRegistry.registerCommandsFor "ssh-client-manager" [
      {
        name = "ssh-client-manager";
        description = "Manage SSH client connections";
        category = "network";
        script = "${config.systemConfig.${moduleConfig.configPath}.sshClientManagerScript}/bin/ncc-ssh-client-manager-main";
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
