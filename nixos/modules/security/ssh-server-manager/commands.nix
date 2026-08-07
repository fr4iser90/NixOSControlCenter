{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";

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
    domainGui="${(getModuleApi "gui-engine").domainGui pkgs}/bin/ncc-domain-gui"
    cmd="''${1:-}"
    case "$cmd" in
      ""|gui)
        exec "$domainGui" ssh
        ;;
      help|-h|--help)
        cat <<EOF
ncc ssh — SSH client & server

Usage:
  ncc ssh                       GUI
  ncc ssh client …              Client connections
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
      status) exec ${sshStatusScript}/bin/ncc-ssh-status ;;
      *)
        echo "Unknown or incomplete: ncc ssh $cmd" >&2
        echo "Try: ncc ssh help" >&2
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
