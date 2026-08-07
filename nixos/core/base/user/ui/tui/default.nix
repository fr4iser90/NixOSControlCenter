{ config, lib, pkgs, getModuleApi, getModuleConfig }:

let
  moduleName = baseNameOf ../../..; # core/base/user
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = (getModuleApi "tui-engine").fromConfig config;
  modulePath = ../../..;

  userTui = tuiEngine.domainTui.buildDomainTui {
    name = moduleName;
    title = "👤 User Manager";
    domain = moduleName;
    footer = "ncc ${moduleName} <action> • q to quit";
    extraInfo = "User commands are not implemented yet.";
    statsContent = ''
Users:
- module enabled: ${toString (cfg.enable or true)}
- TODO: list configured users
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config moduleName);
    layout = null;
    modulePath = modulePath;
  };
in
{
  tuiScript = userTui;
}
