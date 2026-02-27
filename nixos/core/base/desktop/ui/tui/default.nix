 { config, lib, pkgs, getModuleApi, systemConfig }:

let
  cfg = lib.attrByPath ["core" "base" "desktop"] {} systemConfig;
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = config.core.management.tui-engine;
  desktopTui = tuiEngine.domainTui.buildDomainTui {
    name = "desktop";
    title = "🖥️ Desktop Manager";
    domain = "desktop";
    footer = "ncc desktop <action> • q to quit";
    extraInfo = "Desktop commands are not implemented yet.";
    statsContent = ''
Desktop:
- module enabled: ${toString (cfg.enable or true)}
- TODO: add DE status
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config "desktop");
  };
in
{
  tuiScript = desktopTui;
}