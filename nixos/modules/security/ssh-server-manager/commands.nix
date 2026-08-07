{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  sshStatusScript = pkgs.writeShellScriptBin "ncc-ssh-status" ''
    #!/usr/bin/env bash
    echo "${ui.text.header "SSH Status"}"
    if ${lib.optionalString (config.services.openssh.settings.PasswordAuthentication or false) "true" "false"}; then
      echo "${ui.tables.keyValue "Password Auth" "Enabled"}"
    else
      echo "${ui.tables.keyValue "Password Auth" "Disabled"}"
    fi
    SESSIONS=$(ss -tn state established '( dport = :ssh )' | wc -l)
    echo "${ui.tables.keyValue "Active Sessions" "$SESSIONS"}"
    echo "${ui.tables.keyValue "Client Alive Interval" "${toString (config.services.openssh.settings.ClientAliveInterval or 0)}"}"
    echo "${ui.tables.keyValue "Client Alive Count Max" "${toString (config.services.openssh.settings.ClientAliveCountMax or 0)}"}"
  '';

  sshEntry = pkgs.writeShellScriptBin "ncc-ssh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) _ui=tui ;;
        gui|tui)
          echo "Use: ncc ssh --$_a   (not bare '$_a')" >&2
          exit 2
          ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    cmd="''${1:-}"
    case "$cmd" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui ssh'' else guiOff} ;;
          tui)
            echo "Use: ncc ssh client --tui" >&2
            exit 2
            ;;
          *)
            cat <<EOF
ncc ssh — SSH client & server (CLI)

Usage:
  ncc ssh --gui                 Domain GUI
  ncc ssh client […]           Client CLI (manager / verbs)
  ncc ssh client --gui|--tui
  ncc ssh status
  ncc ssh temp-open USER
  ncc ssh force-open USER
  ncc ssh request-access …
  ncc ssh grant-access …
  ncc ssh approve-request …
  ncc ssh deny-request …
  ncc ssh list-requests …
  ncc ssh cleanup-requests …
  ncc ssh monitor
  ncc ssh notify-test
EOF
            ;;
        esac
        ;;
      help|-h|--help)
        exec "$0"
        ;;
      status) exec ${sshStatusScript}/bin/ncc-ssh-status ;;
      *)
        echo "Unknown or incomplete: ncc ssh $cmd" >&2
        echo "Try: ncc ssh   or   ncc ssh client …" >&2
        exit 1
        ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or false)
      (cliRegistry.registerCommandsFor "ssh" [
        {
          name = "ssh";
          domain = "ssh";
          type = "manager";
          description = "SSH client and server management";
          category = "security";
          script = "${sshEntry}/bin/ncc-ssh";
          shortHelp = "ssh - SSH management";
          longHelp = ''
            ncc ssh                 CLI help
            ncc ssh --gui
            ncc ssh client …
            ncc ssh status|temp-open|force-open|…
          '';
        }
        {
          name = "status";
          parent = "ssh";
          domain = "ssh";
          description = "Show SSH server status";
          category = "security";
          script = "${sshStatusScript}/bin/ncc-ssh-status";
          shortHelp = "status - Show SSH server status";
          longHelp = "ncc ssh status";
        }
      ])
    )
  ];
}
