{ config, lib, pkgs, getModuleApi, getModuleConfig, ... }:

let
  cliRegistry = getModuleApi "cli-registry";
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  activeFile = ''"$HOME/.config/ncc/active-target"'';
  credsFile = ''"$HOME/.creds"'';

  listScript = pkgs.writeShellScriptBin "ncc-hosts-list" ''
    set -euo pipefail
    if command -v ncc >/dev/null 2>&1 && ncc ssh client list >/dev/null 2>&1; then
      ncc ssh client list | while IFS='=' read -r host user; do
        [[ -n "$host" && -n "$user" ]] || continue
        printf '%s@%s\n' "$user" "$host"
      done
      exit 0
    fi
    if [[ -f ${credsFile} ]]; then
      while IFS='=' read -r host rest; do
        [[ -z "$host" || "$host" == \#* ]] && continue
        user="''${rest%%:*}"
        [[ -n "$user" ]] || continue
        printf '%s@%s\n' "$user" "$host"
      done < ${credsFile}
    fi
  '';

  entry = pkgs.writeShellScriptBin "ncc-hosts-entry" ''
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) echo "hosts has no TUI; use --gui or CLI" >&2; exit 2 ;;
        gui|tui) echo "Use: ncc hosts --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    case "''${1:-}" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui hosts'' else guiOff} ;;
          *)
            cat <<EOF
ncc hosts — Fleet targets (SSH client list)

Usage:
  ncc hosts                 Help
  ncc hosts --gui           Hosts GUI
  ncc hosts list            user@host from ~/.creds / ssh client
  ncc hosts show            Active target (or local)
  ncc hosts use local|USER@HOST
  ncc hosts add HOST USER   → ncc ssh client add
  ncc hosts remove HOST     → ncc ssh client delete
EOF
            ;;
        esac
        ;;
      list) exec ${listScript}/bin/ncc-hosts-list ;;
      show)
        if [[ -f ${activeFile} ]]; then
          tr -d '\n' < ${activeFile}
          echo
        else
          echo "local"
        fi
        ;;
      use)
        target="''${2:-}"
        mkdir -p "$HOME/.config/ncc"
        if [[ -z "$target" || "$target" == "local" ]]; then
          rm -f ${activeFile}
          echo "Target: local"
        else
          printf '%s\n' "$target" > ${activeFile}
          echo "Target: $target"
        fi
        ;;
      add)
        host="''${2:-}"; user="''${3:-}"
        if [[ -z "$host" || -z "$user" ]]; then
          echo "Usage: ncc hosts add HOST USER" >&2
          exit 2
        fi
        exec ncc ssh client add "$host" "$user"
        ;;
      remove|delete)
        host="''${2:-}"
        if [[ -z "$host" ]]; then
          echo "Usage: ncc hosts remove HOST" >&2
          exit 2
        fi
        exec ncc ssh client delete "$host"
        ;;
      help|-h|--help) exec "$0" ;;
      *) echo "Unknown: ncc hosts $1" >&2; exit 1 ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "hosts" {
      label = "Hosts";
      description = "Fleet targets (SSH hosts)";
      enabled = true;
      group = "core";
    })
    (cliRegistry.registerGuiPage "hosts" ./ui/gui)
    (cliRegistry.registerCommandsFor "hosts" [
      {
        name = "hosts";
        domain = "hosts";
        type = "manager";
        description = "Fleet host targets";
        category = "management";
        script = "${entry}/bin/ncc-hosts-entry";
        shortHelp = "hosts - Fleet targets (SSH list)";
        longHelp = ''
          ncc hosts                 Help
          ncc hosts --gui
          ncc hosts list|show|use|add|remove …
        '';
      }
    ])
  ];
}
