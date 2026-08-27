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
  wifiCli = import ./scripts/wifi/default.nix { inherit pkgs getModuleApi; };
  netCli = import ./scripts/network-status.nix { inherit pkgs getModuleApi; };
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  entry = pkgs.writeShellScriptBin "ncc-network-entry" ''
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) _ui=tui ;;
        gui|tui) echo "Use: ncc network --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    case "''${1:-}" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui network'' else guiOff} ;;
          tui)
            ${if tuiOn then ''exec ${networkTui}/bin/ncc-network-tui'' else tuiOff}
            ;;
          *)
            cat <<EOF
ncc network — Network (CLI)

Usage:
  ncc network                 Help
  ncc network --gui           Domain GUI
  ncc network --tui           TUI (if enabled)
  ncc network status [--json]
  ncc network wifi …          WiFi (scan/list/status/connect/…)
  ncc network ethernet …      Wired (status/disconnect/reconnect)
EOF
            ;;
        esac
        ;;
      status) shift; exec ${netCli.statusScript}/bin/ncc-network-status "$@" ;;
      wifi) shift; exec ${wifiCli.wifiRouter}/bin/ncc-wifi-router "$@" ;;
      ethernet|eth) shift; exec ${netCli.ethernetRouter}/bin/ncc-ethernet-router "$@" ;;
      help|-h|--help) exec "$0" ;;
      *)
        echo "Usage: ncc network [--gui|--tui] | status | wifi … | ethernet …" >&2
        exit 1
        ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "network" {
      label = "Network";
      description = "Network and WiFi";
      enabled = cfg.enable != false;
      group = "core";
    })
    (cliRegistry.registerGuiPage "network" ./ui/gui)
    # Core: commands always registered so GUI can manage / re-enable when off.
    (cliRegistry.registerCommandsFor "network" (
      [
        {
          name = "network";
          domain = "network";
          description = "Network manager";
          category = "base";
          script = "${entry}/bin/ncc-network-entry";
          type = "manager";
          shortHelp = "network - Network Manager";
          longHelp = ''
            Manage Wi-Fi, ethernet, and network overview.

            Examples:
              ncc network status
              ncc network wifi scan
              ncc network ethernet status
              ncc network --gui
          '';
        }
        {
          name = "status";
          parent = "network";
          domain = "network";
          description = "Network overview status";
          category = "base";
          script = "${netCli.statusScript}/bin/ncc-network-status";
          shortHelp = "status - Overview (devices, online)";
          longHelp = ''
            Show devices and online status.

            Examples:
              ncc network status
              ncc network status --json
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
          shortHelp = "wifi - WiFi management";
          longHelp = ''
            Scan, connect, and manage saved Wi-Fi networks.

            Examples:
              ncc network wifi scan
              ncc network wifi list
              ncc network wifi connect "MySSID"
              ncc network wifi disconnect
          '';
        }
        {
          name = "ethernet";
          parent = "network";
          domain = "network";
          description = "Ethernet / wired link";
          category = "base";
          script = "${netCli.ethernetRouter}/bin/ncc-ethernet-router";
          type = "manager";
          shortHelp = "ethernet - Wired link";
          longHelp = ''
            Check or cycle the wired link.

            Examples:
              ncc network ethernet status
              ncc network ethernet disconnect
              ncc network ethernet reconnect
          '';
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
          shortHelp = "tui - Network TUI (prefer: ncc network --tui)";
          longHelp = ''
            Open the network terminal UI.

            Examples:
              ncc network --tui
          '';
        }
      ]
    ))
  ];
}
