{ config, lib, pkgs, getModuleApi, getModuleConfig, ... }:

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  networkTui =
    if tuiOn
    then (import ./ui/tui/default.nix { inherit config lib pkgs getModuleApi getModuleConfig; }).tuiScript
    else null;
  wifiCli = import ./scripts/wifi/default.nix { inherit pkgs; };
  domainGui = (getModuleApi "gui-engine").domainGui pkgs;

  entry = pkgs.writeShellScriptBin "ncc-network-entry" ''
    set -euo pipefail
    case "''${1:-}" in
      ""|gui) exec ${domainGui}/bin/ncc-domain-gui network ;;
      tui)
        ${if tuiOn then ''exec ${networkTui}/bin/ncc-network-tui'' else tuiOff}
        ;;
      *)
        echo "Usage: ncc network | ncc network tui | ncc network wifi …" >&2
        exit 1
        ;;
    esac
  '';
in
{
  config = lib.mkIf (cfg.enable or true) (
    cliRegistry.registerCommandsFor "network" (
      [
        {
          name = "network";
          domain = "network";
          description = "Network manager (GUI)";
          category = "base";
          script = "${entry}/bin/ncc-network-entry";
          type = "manager";
          shortHelp = "network - Network Manager (GUI)";
          longHelp = ''
            ncc network
            ncc network tui
            ncc network wifi scan|list|status|connect|disconnect|forget
          '';
        }
        {
          name = "wifi";
          parent = "network";
          domain = "network";
          description = "WiFi management";
          category = "base";
          script = "${wifiCli.wifiRouter}/bin/ncc-wifi-router";
          type = "manager";
          shortHelp = "wifi - WiFi scan/list/status/connect";
          longHelp = "ncc network wifi scan|list|status|connect|disconnect|forget";
        }
      ]
      ++ lib.optionals tuiOn [
        {
          name = "tui";
          parent = "network";
          domain = "network";
          description = "Network TUI";
          category = "base";
          script = "${networkTui}/bin/ncc-network-tui";
          type = "manager";
          shortHelp = "tui - Network TUI";
          longHelp = "ncc network tui";
        }
      ]
    )
  );
}
