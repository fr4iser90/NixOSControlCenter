{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  bubbleTeaTui =
    if tuiOn
    then ((getModuleApi "tui-engine").fromConfig config).moduleManagerTuiScript
    else null;
  modulesGui = (import ./gui/default.nix { inherit pkgs getModuleApi config; }).nccModulesGui;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  discovery = (import ./lib/runtime_discovery.nix { inherit lib pkgs; }).runtimeDiscovery;

  modulesEntry = pkgs.writeShellScriptBin "ncc-modules-entry" ''
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) _ui=tui ;;
        gui|tui) echo "Use: ncc modules --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    case "''${1:-}" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${modulesGui}/bin/ncc-modules-gui'' else guiOff} ;;
          tui)
            ${if tuiOn then ''exec ${bubbleTeaTui}/bin/ncc-module-manager-tui'' else tuiOff}
            ;;
          *)
            cat <<EOF
ncc modules — Module management (CLI)

Usage:
  ncc modules                 Help
  ncc modules --gui           Modules GUI
  ncc modules --tui           TUI (if enabled)
EOF
            ;;
        esac
        ;;
      help|-h|--help) exec "$0" ;;
      *)
        echo "Usage: ncc modules [--gui|--tui]" >&2
        exit 1
        ;;
    esac
  '';

  getModuleData = pkgs.writeShellScriptBin "ncc-modules-get-data" ''
    ${discovery}
  '';
in
  cliRegistry.registerCommandsFor "modules" (
    [
      {
        name = "modules";
        domain = "modules";
        description = "Module management (GUI)";
        category = "system";
        script = "${modulesEntry}/bin/ncc-modules-entry";
        type = "manager";
        permission = "system.manage";
        requiresSudo = true;
        shortHelp = "modules - Module management (GUI)";
        longHelp = ''
          ncc modules       GUI
          ncc modules tui   Terminal TUI (if tui-engine.enable)
        '';
      }
      {
        name = "get-module-data";
        domain = "modules";
        parent = "modules";
        internal = true;
        description = "Internal discovery helper";
        category = "system";
        script = "${getModuleData}/bin/ncc-modules-get-data";
        shortHelp = "get-module-data - Internal";
      }
    ]
    ++ optionals tuiOn [
      {
        name = "tui";
        domain = "modules";
        parent = "modules";
        description = "Modules TUI";
        category = "system";
        script = "${bubbleTeaTui}/bin/ncc-module-manager-tui";
        type = "manager";
        permission = "system.manage";
        requiresSudo = true;
        shortHelp = "tui - Modules TUI";
        longHelp = "ncc modules tui";
      }
    ]
  )
