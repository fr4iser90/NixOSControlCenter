{ config, lib, pkgs, getModuleApi, systemConfig, moduleName ? "vm" }:

let
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = config.core.management.tui-engine;
  availableDistros = builtins.attrNames (import ../../lib { inherit lib pkgs; }).distros;
  # Get module path (go up from ui/tui/default.nix to module root)
  # ui/tui/default.nix -> ../.. -> vm/
  modulePath = ../..;
  
  vmTui = tuiEngine.domainTui.buildDomainTui {
    name = "vm";
    title = "🖥️ VM Manager";
    domain = "vm";
    footer = "ncc vm <action> • q to quit";
    extraInfo = "Commands: status, list, test-<distro>-run/reset.";
    statsContent = ''
VM:
- Distros: ${toString (builtins.length availableDistros)}
- Commands: status, list, test-<distro>-run/reset
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config "vm");
    modulePath = modulePath;  # REQUIRED - no fallbacks
  };
in
{
  tuiScript = vmTui;
}