{ config, lib, pkgs, getModuleApi, systemConfig }:

let
  cfg = lib.attrByPath ["core" "base" "network"] {} systemConfig;
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = config.core.management.tui-engine;
  # Get module path (go up from ui/tui/default.nix to module root)
  modulePath = ../../..;
  
  networkTui = tuiEngine.domainTui.buildDomainTui {
    name = "network";
    title = "🌐 Network Manager";
    domain = "network";
    footer = "ncc network <action> • q to quit";
    extraInfo = "Network commands are not implemented yet.";
    statsContent = ''
Network:
- module enabled: ${toString (cfg.enable or true)}
- TODO: add status checks
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config "network");
    modulePath = modulePath;  # REQUIRED - no fallbacks
  };
in
{
  tuiScript = networkTui;
}