{ config, lib, pkgs, getModuleApi, systemConfig }:

let
  cfg = lib.attrByPath ["core" "base" "user"] {} systemConfig;
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = config.core.management.tui-engine;
  # Get module path (go up from ui/tui/default.nix to module root)
  modulePath = ../../..;
  
  userTui = tuiEngine.domainTui.buildDomainTui {
    name = "user";
    title = "👤 User Manager";
    domain = "user";
    footer = "ncc user <action> • q to quit";
    extraInfo = "User commands are not implemented yet.";
    statsContent = ''
Users:
- module enabled: ${toString (cfg.enable or true)}
- TODO: list configured users
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config "user");
    modulePath = modulePath;  # REQUIRED - no fallbacks
  };
in
{
  tuiScript = userTui;
}