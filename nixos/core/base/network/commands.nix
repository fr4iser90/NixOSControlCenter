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
  ncc network wifi scan|list|status|connect|disconnect|forget
EOF
            ;;
        esac
        ;;
      help|-h|--help) exec "$0" ;;
      *)
        echo "Usage: ncc network [--gui|--tui] | ncc network wifi …" >&2
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
      enabled = cfg.enable or true;
      group = "core";
    })
    (cliRegistry.registerGuiPage "network" ./ui/gui)
    (lib.mkIf (cfg.enable or true) (
    cliRegistry.registerCommandsFor "network" (
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
            ncc network                 CLI help
            ncc network --gui|--tui
            ncc network wifi …
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
          shortHelp = "tui - Network TUI (prefer: ncc network --tui)";
          longHelp = "ncc network --tui";
        }
      ]
    )
    ))
  ];
}
