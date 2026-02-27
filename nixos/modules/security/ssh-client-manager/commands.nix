{ config, lib, pkgs, getModuleConfig, getModuleApi, moduleName, ... }:

with lib;

let
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  sshClientTui = (import ./ui/tui/default.nix { inherit config lib pkgs getModuleApi systemConfig; }).tuiScript;
  scriptModule = import ./scripts/ssh-client-manager.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi;
  };
  scriptPath = scriptModule.sshClientManagerScript;
 in {
  config = mkIf (cfg.enable or false)
    (lib.mkMerge [
      (cliRegistry.registerCommandsFor "ssh-client-manager" [
      {
        name = "ssh-client-manager";
        domain = "ssh-client-manager";
        description = "Manage SSH client connections";
        category = "network";
        script = "${scriptPath}/bin/ncc-ssh-client-manager-main";
        arguments = [];
        dependencies = [ "openssh" "fzf" "sshpass" ];
        shortHelp = "ssh-client-manager - Manage SSH client connections";
        longHelp = ''
          Interactive SSH client manager for managing SSH connections and keys.
          Provides a user-friendly interface for connecting to SSH servers,
          managing SSH keys, and configuring connection settings.
        '';
      }
      {
        name = "ssh-client";
        domain = "ssh-client-manager";
        description = "SSH client manager TUI";
        category = "network";
        script = "${sshClientTui}/bin/ncc-ssh-client-tui";
        arguments = [];
        type = "manager";
        shortHelp = "ssh-client - SSH Client Manager (TUI)";
        longHelp = ''
          TUI wrapper for SSH client manager.
        '';
      }
      ])
    ]);
}
