{ config, lib, pkgs, getModuleApi, getModuleConfig, getModuleMetadata, ... }:

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  hardwareCli = import ./scripts/ncc-hardware.nix {
    inherit pkgs getModuleMetadata getModuleApi;
  };

  statusBin = pkgs.writeShellScriptBin "ncc-hardware-status" ''
    exec ${hardwareCli}/bin/ncc-hardware status "$@"
  '';

  setBin = pkgs.writeShellScriptBin "ncc-hardware-set" ''
    exec ${hardwareCli}/bin/ncc-hardware set "$@"
  '';

  entry = pkgs.writeShellScriptBin "ncc-hardware-entry" ''
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui)
          echo "hardware has no TUI; use: ncc hardware --gui" >&2
          exit 2
          ;;
        gui|tui) echo "Use: ncc hardware --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    case "''${1:-}" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui hardware'' else guiOff} ;;
          *)
            cat <<EOF
ncc hardware — Hardware inventory and auto-detection

Usage:
  ncc hardware                 Help
  ncc hardware --gui           Domain GUI
  ncc hardware status [--json]
  ncc hardware set autoDetect=true|false
EOF
            ;;
        esac
        ;;
      status) shift; exec ${statusBin}/bin/ncc-hardware-status "$@" ;;
      set) shift; exec ${setBin}/bin/ncc-hardware-set "$@" ;;
      help|-h|--help) exec "$0" ;;
      *)
        echo "Usage: ncc hardware [--gui] | status [--json] | set autoDetect=…" >&2
        exit 1
        ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "hardware" {
      label = "Hardware";
      description = "CPU, GPU, RAM and auto-detection";
      enabled = true;
      group = "core";
    })
    (cliRegistry.registerGuiPage "hardware" ./ui/gui)
    (cliRegistry.registerCommandsFor "hardware" [
        {
          name = "hardware";
          domain = "hardware";
          description = "Hardware inventory and auto-detection";
          category = "base";
          script = "${entry}/bin/ncc-hardware-entry";
          type = "manager";
          shortHelp = "hardware - Hardware";
          longHelp = ''
            Show hardware inventory and toggle auto-detection.

            Examples:
              ncc hardware status
              ncc hardware status --json
              ncc hardware --gui
              sudo ncc hardware set autoDetect=true
          '';
        }
        {
          name = "status";
          parent = "hardware";
          domain = "hardware";
          description = "Show configured vs detected hardware";
          category = "base";
          script = "${statusBin}/bin/ncc-hardware-status";
          shortHelp = "status - Hardware inventory";
          longHelp = ''
            Show configured vs detected hardware (optional live probe JSON).

            Examples:
              ncc hardware status
              ncc hardware status --json
          '';
        }
        {
          name = "set";
          parent = "hardware";
          domain = "hardware";
          description = "Toggle hardware auto-detection (enableChecks)";
          category = "base";
          script = "${setBin}/bin/ncc-hardware-set";
          requiresSudo = true;
          shortHelp = "set - Toggle autoDetect";
          longHelp = ''
            Toggle hardware auto-detection (system-manager enableChecks).

            Examples:
              sudo ncc hardware set autoDetect=true
              sudo ncc hardware set autoDetect=false
          '';
        }
      ]
    )
  ];
}
