{ config, lib, pkgs, getModuleApi, getModuleConfig }:

let
  moduleName = baseNameOf ../../..; # core/base/network
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = (getModuleApi "tui-engine").fromConfig config;
  modulePath = ../../..;

  networkTui = tuiEngine.domainTui.buildDomainTui {
    name = moduleName;
    title = "🌐 Network Manager";
    domain = moduleName;
    footer = "ncc ${moduleName} <action> • q to quit";
    extraInfo = "Network commands are not implemented yet.";
    statsContent = ''
Network:
- module enabled: ${toString (cfg.enable or true)}
- TODO: add status checks
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config moduleName);
    layout = null;
    modulePath = modulePath;
  };
in
{
  tuiScript = networkTui;
}
