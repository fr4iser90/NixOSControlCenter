{ config, lib, pkgs, getModuleApi }:

let
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = (getModuleApi "tui-engine").fromConfig config;
  # Get module path (go up from ui/tui/domain.nix → system-manager root)
  modulePath = ../..;
  
  systemTui = tuiEngine.domainTui.buildDomainTui {
    name = "system";
    title = "🛠️ System Manager";
    domain = "system";
    footer = "ncc system <action> • q to quit";
    extraInfo = "Includes build, update, report, migrate-config.";
    statsContent = ''
System:
- Actions: build, update, report
- Config: migrate-config, validate-config
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config "system");
    layout = null;
    modulePath = modulePath;
  };
in
{
  tuiScript = systemTui;
}
