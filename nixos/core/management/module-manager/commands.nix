{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  bubbleTeaTui =
    if tuiOn
    then ((getModuleApi "tui-engine").fromConfig config).moduleManagerTuiScript
    else null;
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  discoveryPkg = import ./lib/runtime_discovery.nix { inherit lib pkgs; };
  discoverBin = "${discoveryPkg.discoveryBin}/bin/ncc-modules-discover";
  mmLib = import ./lib/default.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi getModuleMetadata;
  };
  updateBin = "${mmLib.updateModuleConfig}/bin/update-module-config";

  # Modules that must not be disabled via CLI/GUI (break NCC itself)
  protected = "module-manager cli-registry nixos-control-center system-manager";

  listScript = pkgs.writeShellScriptBin "ncc-modules-list" ''
    set -euo pipefail
    JSON_OUT=false
    for a in "$@"; do
      case "$a" in
        --json|-j) JSON_OUT=true ;;
        --help|-h)
          echo "Usage: ncc modules list [--json]"
          exit 0
          ;;
      esac
    done

    tmp=$(mktemp)
    err=$(mktemp)
    trap 'rm -f "$tmp" "$err"' EXIT

    if ! ${discoverBin} >"$tmp" 2>"$err"; then
      echo "Failed to discover modules." >&2
      [[ -s "$err" ]] && cat "$err" >&2
      exit 1
    fi

    if ! ${pkgs.jq}/bin/jq -e 'type == "array"' "$tmp" >/dev/null 2>&1; then
      echo "Failed to discover modules (invalid JSON)." >&2
      [[ -s "$err" ]] && cat "$err" >&2
      exit 1
    fi

    if [[ "$JSON_OUT" == true ]]; then
      ${pkgs.jq}/bin/jq -c '.' "$tmp"
      exit 0
    fi

    ${pkgs.jq}/bin/jq -r '
      .[] |
      "\(.name)\t\(.status)\t\(.category)\t\(.version // "1.0")\t\(.description // "")"
    ' "$tmp"
  '';

  showScript = pkgs.writeShellScriptBin "ncc-modules-show" ''
    set -euo pipefail
    name="''${1:-}"
    if [[ -z "$name" ]]; then
      echo "Usage: ncc modules show NAME" >&2
      exit 2
    fi
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    if ! ${discoverBin} >"$tmp" 2>/dev/null; then
      echo "Failed to discover modules." >&2
      exit 1
    fi

    row=$(${pkgs.jq}/bin/jq -c --arg n "$name" '.[] | select(.name == $n or .id == $n)' "$tmp" | head -1)
    if [[ -z "$row" ]]; then
      echo "Module not found: $name" >&2
      exit 1
    fi
    echo "$row" | ${pkgs.jq}/bin/jq -r '
      "name=\(.name)",
      "status=\(.status)",
      "category=\(.category)",
      "version=\(.version // "1.0")",
      "path=\(.path // "")",
      "description=\(.description // "")"
    '
  '';

  setEnableScript = pkgs.writeShellScriptBin "ncc-modules-set-enable" ''
    set -euo pipefail
    action="''${1:-}"
    name="''${2:-}"
    shift 2 || true
    DO_REBUILD=false
    for a in "$@"; do
      case "$a" in
        --rebuild|-r) DO_REBUILD=true ;;
        --help|-h)
          echo "Usage: sudo ncc modules enable|disable NAME [--rebuild]"
          exit 0
          ;;
      esac
    done

    if [[ "$action" != "enable" && "$action" != "disable" ]]; then
      echo "Internal: bad action" >&2
      exit 2
    fi
    if [[ -z "$name" ]]; then
      echo "Usage: ncc modules $action NAME [--rebuild]" >&2
      exit 2
    fi

    value=true
    [[ "$action" == "disable" ]] && value=false

    PROTECTED="${protected}"
    for p in $PROTECTED; do
      if [[ "$name" == "$p" && "$value" == "false" ]]; then
        echo "Refusing to disable protected module: $name" >&2
        exit 1
      fi
    done

    ${updateBin} "$name" "$value"

    if [[ "$DO_REBUILD" == true ]]; then
      exec ncc system build switch
    fi
  '';

  getModuleData = pkgs.writeShellScriptBin "ncc-modules-get-data" ''
    exec ${discoverBin}
  '';

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
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui modules'' else guiOff} ;;
          tui)
            ${if tuiOn then ''exec ${bubbleTeaTui}/bin/ncc-module-manager-tui'' else tuiOff}
            ;;
          *)
            cat <<EOF
ncc modules — Enable / disable NCC modules

Usage:
  ncc modules                 Help
  ncc modules --gui           Modules GUI
  ncc modules --tui           TUI (if enabled)
  ncc modules list [--json]   List discovered modules
  ncc modules show NAME       Module details (key=value)
  ncc modules enable NAME [--rebuild]
  ncc modules disable NAME [--rebuild]

Enable/disable write systemConfig (needs write access to /etc/nixos; use sudo).
Protected (cannot disable): ${protected}
EOF
            ;;
        esac
        ;;
      list) shift; exec ${listScript}/bin/ncc-modules-list "$@" ;;
      show) shift; exec ${showScript}/bin/ncc-modules-show "$@" ;;
      enable) shift; exec ${setEnableScript}/bin/ncc-modules-set-enable enable "$@" ;;
      disable) shift; exec ${setEnableScript}/bin/ncc-modules-set-enable disable "$@" ;;
      help|-h|--help) exec "$0" ;;
      *)
        echo "Unknown: ncc modules $1" >&2
        echo "Try: ncc modules  (help)" >&2
        exit 1
        ;;
    esac
  '';
in
{
  config = mkMerge [
    (cliRegistry.registerGuiDomain "modules" {
      label = "Modules";
      description = "Turn NCC modules on or off";
      enabled = true;
      group = "core";
    })
    (cliRegistry.registerGuiPage "modules" ./ui/gui)
    (cliRegistry.registerCommandsFor "modules" (
      [
        {
          name = "modules";
          domain = "modules";
          description = "Modules";
          category = "system";
          script = "${modulesEntry}/bin/ncc-modules-entry";
          type = "manager";
          permission = "system.manage";
          requiresSudo = true;
          shortHelp = "modules - Modules";
          longHelp = ''
            ncc modules                 Help
            ncc modules --gui|--tui
            ncc modules list [--json]
            ncc modules show NAME
            ncc modules enable NAME [--rebuild]
            ncc modules disable NAME [--rebuild]
          '';
        }
        {
          name = "list";
          domain = "modules";
          parent = "modules";
          description = "List NCC modules";
          category = "system";
          script = "${listScript}/bin/ncc-modules-list";
          shortHelp = "list - List modules";
        }
        {
          name = "show";
          domain = "modules";
          parent = "modules";
          description = "Show module details";
          category = "system";
          script = "${showScript}/bin/ncc-modules-show";
          shortHelp = "show - Module details";
        }
        {
          name = "enable";
          domain = "modules";
          parent = "modules";
          description = "Enable a module in systemConfig";
          category = "system";
          script = "${pkgs.writeShellScriptBin "ncc-modules-enable-cmd" ''
            exec ${setEnableScript}/bin/ncc-modules-set-enable enable "$@"
          ''}/bin/ncc-modules-enable-cmd";
          permission = "system.manage";
          requiresSudo = true;
          shortHelp = "enable - Enable module";
        }
        {
          name = "disable";
          domain = "modules";
          parent = "modules";
          description = "Disable a module in systemConfig";
          category = "system";
          script = "${pkgs.writeShellScriptBin "ncc-modules-disable-cmd" ''
            exec ${setEnableScript}/bin/ncc-modules-set-enable disable "$@"
          ''}/bin/ncc-modules-disable-cmd";
          permission = "system.manage";
          requiresSudo = true;
          shortHelp = "disable - Disable module";
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
          longHelp = "ncc modules --tui";
        }
      ]
    ))
  ];
}
