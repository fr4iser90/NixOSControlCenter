{ config, lib, pkgs, getModuleApi }:

let
  moduleName = baseNameOf ../..; # modules/infrastructure/vm
  cliRegistry = getModuleApi "cli-registry";
  tuiEngine = (getModuleApi "tui-engine").fromConfig config;
  availableDistros = builtins.attrNames (import ../../lib { inherit lib pkgs; }).distros;
  modulePath = ../..;

  vmTui = tuiEngine.domainTui.buildDomainTui {
    name = moduleName;
    title = "🖥️ VM Manager";
    domain = moduleName;
    footer = "ncc ${moduleName} <action> • q to quit";
    extraInfo = "Commands: status, list, test-<distro>-run/reset.";
    statsContent = ''
VM:
- Distros: ${toString (builtins.length availableDistros)}
- Commands: status, list, test-<distro>-run/reset
    '';
    commands = lib.filter (cmd: !(cmd.internal or false)) (cliRegistry.getCommandsByDomain config moduleName);
    layout = null;
    modulePath = modulePath;
  };
in
{
  tuiScript = vmTui;
}
