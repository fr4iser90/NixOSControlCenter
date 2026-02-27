{ config, lib, pkgs, getModuleApi, systemConfig }:

let
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = config.core.management.tui-engine;
  sshClientTui = tuiEngine.domainTui.buildDomainTui {
    name = "ssh-client";
    title = "🔐 SSH Client Manager";
    domain = "ssh-client-manager";
    footer = "ncc ssh-client-manager <action> • q to quit";
    extraInfo = "This module uses an interactive CLI for managing SSH connections.";
    statsContent = ''
SSH Client:
- dependencies: openssh, fzf
- commands: ssh-client-manager
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config "ssh-client-manager");
    layout = "medium";
  };
in
{
  tuiScript = sshClientTui;
}