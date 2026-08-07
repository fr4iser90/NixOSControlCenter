{ config, lib, pkgs, getModuleApi, getModuleConfig, ... }:

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  desktopTui =
    if tuiOn
    then (import ./ui/tui/default.nix { inherit config lib pkgs getModuleApi getModuleConfig; }).tuiScript
    else null;
  domainGui = (getModuleApi "gui-engine").domainGui pkgs;

  entry = pkgs.writeShellScriptBin "ncc-desktop-entry" ''
    set -euo pipefail
    case "''${1:-}" in
      ""|gui) exec ${domainGui}/bin/ncc-domain-gui desktop ;;
      tui)
        ${if tuiOn then ''exec ${desktopTui}/bin/ncc-desktop-tui'' else tuiOff}
        ;;
      *) echo "Usage: ncc desktop | ncc desktop tui" >&2; exit 1 ;;
    esac
  '';
in
{
  config = lib.mkIf (cfg.enable or true)
    (cliRegistry.registerCommandsFor "desktop" (
      [
        {
          name = "desktop";
          domain = "desktop";
          description = "Desktop manager (GUI)";
          category = "base";
          script = "${entry}/bin/ncc-desktop-entry";
          type = "manager";
          shortHelp = "desktop - Desktop Manager (GUI)";
          longHelp = ''
            ncc desktop       GUI
            ncc desktop tui   Terminal TUI (if enabled)
          '';
        }
      ]
      ++ lib.optionals tuiOn [
        {
          name = "tui";
          parent = "desktop";
          domain = "desktop";
          description = "Desktop TUI";
          category = "base";
          script = "${desktopTui}/bin/ncc-desktop-tui";
          type = "manager";
          shortHelp = "tui - Desktop TUI";
          longHelp = "ncc desktop tui";
        }
      ]
    ));
}
