{ config, lib, pkgs, getModuleConfig, getModuleApi, moduleName, ... }:

with lib;

let
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  scriptModule = import ./scripts/ssh-client-manager.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi;
  };
  scriptPath = scriptModule.sshClientManagerScript;
  sshClientTui = (import ./ui/tui/default.nix { inherit config lib pkgs systemConfig scriptPath; sshClientCfg = cfg; }).tuiScript;
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
        name = "list";
        domain = "ssh-client-manager";
        parent = "ssh-client-manager";
        description = "List saved SSH servers";
        category = "network";
        script = "${scriptPath}/bin/ncc-ssh-client-manager-main";
        arguments = [ "list" ];
        shortHelp = "list - List saved SSH servers";
      }
      {
        name = "add";
        domain = "ssh-client-manager";
        parent = "ssh-client-manager";
        description = "Add a new SSH server";
        category = "network";
        script = "${scriptPath}/bin/ncc-ssh-client-manager-main";
        arguments = [ "add" ];
        shortHelp = "add - Add a new SSH server";
      }
      {
        name = "edit";
        domain = "ssh-client-manager";
        parent = "ssh-client-manager";
        description = "Edit an existing SSH server";
        category = "network";
        script = "${scriptPath}/bin/ncc-ssh-client-manager-main";
        arguments = [ "edit" ];
        shortHelp = "edit - Edit an SSH server";
      }
      {
        name = "delete";
        domain = "ssh-client-manager";
        parent = "ssh-client-manager";
        description = "Delete an SSH server";
        category = "network";
        script = "${scriptPath}/bin/ncc-ssh-client-manager-main";
        arguments = [ "delete" ];
        shortHelp = "delete - Delete an SSH server";
      }
      {
        name = "connect";
        domain = "ssh-client-manager";
        parent = "ssh-client-manager";
        description = "Connect to an SSH server";
        category = "network";
        script = "${scriptPath}/bin/ncc-ssh-client-manager-main";
        arguments = [ "connect" ];
        shortHelp = "connect - Connect to an SSH server";
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
