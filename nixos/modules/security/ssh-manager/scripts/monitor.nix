{ config, lib, pkgs, getModuleApi, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";

  monitorScript = pkgs.writeScriptBin "ssh-monitor" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    LOCKFILE="/tmp/ssh-monitor.lock"
    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
      ${ui.messages.error "Another instance is running."}
      exit 1
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "SSH monitor"}
    fi

    ${ui.messages.loading "Following sshd journal (Ctrl+C to stop)…"}
    ${ui.tables.keyValue "Source" "journalctl -f -u sshd"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc ssh status   (after stopping monitor)"}
    fi

    ACTIVE=0
    TOTAL=0
    FAILED=0

    ${pkgs.systemd}/bin/journalctl -f -u sshd | while read -r line; do
      if echo "$line" | grep -q "Accepted \(password\|publickey\|keyboard-interactive\) for"; then
        USER=$(echo "$line" | grep -oP "for \K[^ ]+" || true)
        IP=$(echo "$line" | grep -oP "from \K[^ ]+" || true)
        METHOD=$(echo "$line" | grep -oP "Accepted \K[^ ]+" || true)
        ACTIVE=$((ACTIVE + 1))
        TOTAL=$((TOTAL + 1))
        ${ui.messages.success "New SSH connection: $USER@$IP ($METHOD)"}
        ${ui.tables.keyValue "Active" "$ACTIVE"}
        ${ui.tables.keyValue "Total" "$TOTAL"}
      fi

      if echo "$line" | grep -q "Disconnected from"; then
        USER=$(echo "$line" | grep -oP "Disconnected from user \K[^ ]+" || true)
        IP=$(echo "$line" | grep -oP "from \K[^ ]+" || true)
        if [ -n "''${USER:-}" ]; then
          ACTIVE=$((ACTIVE - 1))
          if [ "$ACTIVE" -lt 0 ]; then ACTIVE=0; fi
          ${ui.messages.info "SSH disconnected: $USER@$IP"}
          ${ui.tables.keyValue "Active" "$ACTIVE"}
        fi
      fi

      if echo "$line" | grep -qE "(Failed password for|Failed publickey for|Invalid user)"; then
        REASON=""
        USER=""
        if echo "$line" | grep -q "Invalid user"; then
          USER=$(echo "$line" | grep -oP "Invalid user \K[^ ]+" || true)
          REASON="invalid user"
        elif echo "$line" | grep -q "Failed password for"; then
          USER=$(echo "$line" | grep -oP "Failed password for \K[^ ]+" || true)
          REASON="wrong password"
        elif echo "$line" | grep -q "Failed publickey for"; then
          USER=$(echo "$line" | grep -oP "Failed publickey for \K[^ ]+" || true)
          REASON="wrong publickey"
        fi
        IP=$(echo "$line" | grep -oP "from \K[^ ]+" || true)
        if [ -n "''${USER:-}" ] && [ -n "''${REASON:-}" ]; then
          FAILED=$((FAILED + 1))
          ${ui.messages.warning "Failed SSH attempt: $USER@$IP ($REASON)"}
          ${ui.tables.keyValue "Failed" "$FAILED"}
        fi
      fi
    done
  '';
in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ monitorScript ];
    }
    (cliRegistry.registerCommandsFor "ssh-server-monitor" [
      {
        name = "monitor";
        parent = "ssh";
        domain = "ssh";
        description = "Monitor SSH connections in real-time";
        category = "monitoring";
        script = "${monitorScript}/bin/ssh-monitor";
        dependencies = [ "systemd" ];
        shortHelp = "monitor - Monitor SSH connections";
        longHelp = ''
          Monitors SSH connections in real-time via journalctl -f -u sshd.

          Usage: ncc ssh monitor
        '';
      }
    ])
  ];
}
