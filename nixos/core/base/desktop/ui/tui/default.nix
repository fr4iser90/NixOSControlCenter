{ config, lib, pkgs, getModuleApi, getModuleConfig }:

let
  moduleName = baseNameOf ../../..; # core/base/desktop
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = (getModuleApi "tui-engine").fromConfig config;
  modulePath = ../../..;

  desktopTui = tuiEngine.domainTui.buildDomainTui {
    name = moduleName;
    title = "🖥️ Desktop Manager";
    domain = moduleName;
    footer = "ncc ${moduleName} <action> • q to quit";
    extraInfo = "Desktop commands are not implemented yet.";
    statsContent = ''
Desktop:
- module enabled: ${toString (cfg.enable or true)}
- TODO: add DE status
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config moduleName);
    layout = null;
    modulePath = modulePath;
  };
in
{
  tuiScript = desktopTui;
}
