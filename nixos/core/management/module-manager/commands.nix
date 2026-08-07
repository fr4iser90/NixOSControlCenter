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
  modulesGui = (import ./gui/default.nix { inherit pkgs getModuleApi; }).nccModulesGui;

  discovery = (import ./lib/runtime_discovery.nix { inherit lib pkgs; }).runtimeDiscovery;

  modulesEntry = pkgs.writeShellScriptBin "ncc-modules-entry" ''
    set -euo pipefail
    case "''${1:-}" in
      ""|gui)
        exec ${modulesGui}/bin/ncc-modules-gui
        ;;
      tui)
        ${if tuiOn then ''exec ${bubbleTeaTui}/bin/ncc-module-manager-tui'' else tuiOff}
        ;;
      *)
        echo "Usage: ncc modules | ncc modules tui" >&2
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
