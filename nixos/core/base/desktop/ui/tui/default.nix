 { config, lib, pkgs, getModuleApi, getModuleConfig, moduleName ? "desktop" }:

let
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = config.core.management.tui-engine;
  # Get module path (go up from ui/tui/default.nix to module root)
  modulePath = ../../..;
  
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
    modulePath = modulePath;  # REQUIRED - no fallbacks
  };
in
{
  tuiScript = desktopTui;
}