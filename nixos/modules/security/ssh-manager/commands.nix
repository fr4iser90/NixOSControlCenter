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
  passwordAuth = cfg.passwordAuthentication or true;
  workflowOn = cfg.workflow.enable or false;

  sshStatusScript = pkgs.writeShellScriptBin "ncc-ssh-status" ''
    #!/usr/bin/env bash
    ${ui.text.header "SSH Status"}
    if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
      ${ui.tables.keyValue "Daemon" "active"}
    else
      ${ui.tables.keyValue "Daemon" "inactive"}
    fi
    if ${if passwordAuth then "true" else "false"}; then
      ${ui.tables.keyValue "Mode" "bootstrap - password auth declared ON"}
      ${ui.tables.keyValue "Password Auth (declared)" "Enabled"}
    else
      ${ui.tables.keyValue "Mode" "lockdown - password auth declared OFF"}
      ${ui.tables.keyValue "Password Auth (declared)" "Disabled"}
    fi
    if grep -Eq '^[[:space:]]*PasswordAuthentication[[:space:]]+yes' /etc/ssh/sshd_config 2>/dev/null; then
      ${ui.tables.keyValue "Password Auth (runtime)" "Enabled"}
    else
      ${ui.tables.keyValue "Password Auth (runtime)" "Disabled"}
    fi
    ${ui.tables.keyValue "PermitRootLogin" (cfg.permitRootLogin or "yes")}
    ${ui.tables.keyValue "Workflow" (if workflowOn then "enabled" else "disabled")}
    SESSIONS=$(ss -tn state established '( dport = :ssh )' 2>/dev/null | wc -l)
    ${ui.tables.keyValue "Active Sessions" "$SESSIONS"}
    if ${if passwordAuth then "true" else "false"}; then
      echo ""
      echo "Next: ncc ssh lockdown   (checks keys + recent pubkey login, then writes config)"
      echo "Temporary reopen later: ncc ssh temp-open USER | ncc ssh grant-access USER"
    fi
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
  ncc ssh client […]           Client CLI
  ncc ssh status
  ncc ssh temp-open USER        Password auth ~60s (runtime)
  ncc ssh force-open USER       Until next password login
  ncc ssh grant-access USER …   Timed password auth (runtime)
  ncc ssh lockdown              Guided: password off after keys work

Lockdown keeps the daemon running; only disables password/root password login.
  ncc ssh lockdown --dry-run | --force | --keep-root

${optionalString workflowOn ''
Workflow (optional):
  ncc ssh request-access …
  ncc ssh approve-request …
  ncc ssh list-requests …
  ncc ssh monitor
''}
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
    (cliRegistry.registerGuiDomain "ssh" {
      label = "SSH";
      description = "SSH server and client";
      enabled = (cfg.enable or false) || (cfg.client.enable or false);
      group = "features";
    })
    (cliRegistry.registerGuiPage "ssh" ./client/ui/gui)
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
            ncc ssh status|temp-open|force-open|grant-access|lockdown|…
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
