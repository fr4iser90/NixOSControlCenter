{ config, lib, pkgs, getModuleApi, systemConfig, moduleConfig }:

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = config.core.management.tui-engine;
  cfg = systemConfig.${moduleConfig.configPath};
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
  };
in
{
  tuiScript = lockTui;
}