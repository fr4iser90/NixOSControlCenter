{ config, lib, pkgs, getModuleApi, systemConfig, moduleConfig }:

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = (getModuleApi "tui-engine").fromConfig config;
  cfg = systemConfig.${moduleConfig.configPath};
  # Get module path (go up from ui/tui/default.nix to module root)
  # ui/tui/default.nix -> ../.. -> lock-manager/
  modulePath = ../..;
  
  lockTui = tuiEngine.domainTui.buildDomainTui {
    name = "lock";
    title = "🔒 Lock Manager";
    domain = "lock";
    footer = "ncc lock <action> • q to quit";
    extraInfo = "Snapshot and restore commands.";
    statsContent = ''
Lock Manager:
- snapshots: ${cfg.snapshotDir}
- scanners: desktop, packages, browser
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config "lock");
    layout = null;
    modulePath = modulePath;
  };
in
{
  tuiScript = lockTui;
}
