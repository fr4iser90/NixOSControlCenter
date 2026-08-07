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
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  desktopStatus = pkgs.writeShellScriptBin "ncc-desktop-status" ''
    set -euo pipefail
    cat <<EOF
enable=${if cfg.enable or true then "true" else "false"}
environment=${cfg.environment or "plasma"}
display.manager=${cfg.display.manager or "sddm"}
display.server=${cfg.display.server or "wayland"}
display.session=${cfg.display.session or "plasma"}
theme.dark=${if cfg.theme.dark or true then "true" else "false"}
pinnedAppsAuto=${if cfg.pinnedAppsAuto or true then "true" else "false"}
pinnedAppsForce=${if cfg.pinnedAppsForce or false then "true" else "false"}
EOF
  '';

  entry = pkgs.writeShellScriptBin "ncc-desktop-entry" ''
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) _ui=tui ;;
        gui|tui) echo "Use: ncc desktop --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    case "''${1:-}" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui desktop'' else guiOff} ;;
          tui)
            ${if tuiOn then ''exec ${desktopTui}/bin/ncc-desktop-tui'' else tuiOff}
            ;;
          *)
            cat <<EOF
ncc desktop — Desktop settings (CLI)

Usage:
  ncc desktop                 Help
  ncc desktop --gui           Domain GUI
  ncc desktop --tui           TUI (if enabled)
  ncc desktop status          Current module settings (key=value)
EOF
            ;;
        esac
        ;;
      status) exec ${desktopStatus}/bin/ncc-desktop-status ;;
      help|-h|--help) exec "$0" ;;
      *) echo "Usage: ncc desktop [--gui|--tui] | ncc desktop status" >&2; exit 1 ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "desktop" {
      label = "Desktop";
      description = "Desktop environment settings";
      enabled = cfg.enable or true;
    })
    (cliRegistry.registerGuiPage "desktop" ./ui/gui)
    (lib.mkIf (cfg.enable or true)
      (cliRegistry.registerCommandsFor "desktop" (
        [
          {
            name = "desktop";
            domain = "desktop";
            description = "Desktop manager";
            category = "base";
            script = "${entry}/bin/ncc-desktop-entry";
            type = "manager";
            shortHelp = "desktop - Desktop Manager";
            longHelp = ''
              ncc desktop                 CLI help
              ncc desktop --gui|--tui
              ncc desktop status
            '';
          }
          {
            name = "status";
            parent = "desktop";
            domain = "desktop";
            description = "Show desktop module settings";
            category = "base";
            script = "${desktopStatus}/bin/ncc-desktop-status";
            shortHelp = "status - Desktop settings";
            longHelp = "ncc desktop status";
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
            shortHelp = "tui - Desktop TUI (prefer: ncc desktop --tui)";
            longHelp = "ncc desktop --tui";
          }
        ]
      ))
    )
  ];
}
