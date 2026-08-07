{ config, lib, pkgs, getModuleApi, getModuleConfig, ... }:
let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  userTui =
    if tuiOn
    then (import ./ui/tui/default.nix { inherit config lib pkgs getModuleApi getModuleConfig; }).tuiScript
    else null;
  domainGui = (getModuleApi "gui-engine").domainGui pkgs;

  entry = pkgs.writeShellScriptBin "ncc-user-entry" ''
    set -euo pipefail
    case "''${1:-}" in
      ""|gui) exec ${domainGui}/bin/ncc-domain-gui user ;;
      tui)
        ${if tuiOn then ''exec ${userTui}/bin/ncc-user-tui'' else tuiOff}
        ;;
      *) echo "Usage: ncc user | ncc user tui" >&2; exit 1 ;;
    esac
  '';
in
{
  config = lib.mkIf (cfg.enable or true)
    (cliRegistry.registerCommandsFor "user" (
      [
        {
          name = "user";
          domain = "user";
          description = "User manager (GUI)";
          category = "base";
          script = "${entry}/bin/ncc-user-entry";
          type = "manager";
          shortHelp = "user - User Manager (GUI)";
          longHelp = ''
            ncc user       GUI
            ncc user tui   Terminal TUI (if enabled)
          '';
        }
      ]
      ++ lib.optionals tuiOn [
        {
          name = "tui";
          parent = "user";
          domain = "user";
          description = "User TUI";
          category = "base";
          script = "${userTui}/bin/ncc-user-tui";
          type = "manager";
          shortHelp = "tui - User TUI";
          longHelp = "ncc user tui";
        }
      ]
    ));
}
