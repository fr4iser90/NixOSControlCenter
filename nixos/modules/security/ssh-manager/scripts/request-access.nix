{ config, lib, pkgs, getModuleApi, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";

  requestAccessScript = pkgs.writeScriptBin "ssh-request-access" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    LOCKFILE="/tmp/ssh-request-access.lock"
    REQUESTS_DIR="/var/log/ssh-requests"

    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
      ${ui.messages.error "Another instance is running."}
      exit 1
    fi

    USER="''${1:-}"
    REASON="''${2:-}"
    DURATION="''${3:-300}"

    if [ -z "$USER" ] || [ -z "$REASON" ]; then
      ${ui.messages.error "Usage: ncc ssh request-access USERNAME REASON [DURATION_SECONDS]"}
      ${ui.messages.info "Example: ncc ssh request-access fr4iser 'Need to copy SSH keys' 300"}
      exit 1
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "SSH request-access"}
    fi

    ${ui.messages.loading "Submitting SSH access request for $USER…"}
    ${ui.tables.keyValue "User" "$USER"}
    ${ui.tables.keyValue "Reason" "$REASON"}
    ${ui.tables.keyValue "Duration" "$DURATION seconds"}

    sudo mkdir -p "$REQUESTS_DIR"
    sudo chmod 755 "$REQUESTS_DIR"

    REQUEST_ID="$(date +%Y%m%d_%H%M%S)_$USER"
    REQUEST_FILE="$REQUESTS_DIR/$REQUEST_ID.json"

    sudo tee "$REQUEST_FILE" > /dev/null <<EOF
{
  "id": "$REQUEST_ID",
  "user": "$USER",
  "reason": "$REASON",
  "duration": $DURATION,
  "timestamp": "$(date -Iseconds)",
  "status": "pending",
  "requester_ip": "''${SSH_CLIENT%% *}",
  "hostname": "$(hostname)"
}
EOF

    find "$REQUESTS_DIR" -name "*.json" -mtime +1 -delete 2>/dev/null || true

    ${ui.messages.success "SSH access request submitted"}
    ${ui.tables.keyValue "Request ID" "$REQUEST_ID"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc ssh list-requests pending   (admin: ncc ssh approve-request $REQUEST_ID)"}
    fi
  '';
in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ requestAccessScript ];
    }
    (cliRegistry.registerCommandsFor "ssh-server-request-access" [
      {
        name = "request-access";
        parent = "ssh";
        domain = "ssh";
        description = "Request temporary SSH password access";
        category = "security";
        script = "${requestAccessScript}/bin/ssh-request-access";
        arguments = [ "USERNAME" "REASON" "[DURATION]" ];
        dependencies = [ ];
        shortHelp = "request-access USERNAME REASON [DURATION] - Request password access";
        longHelp = ''
          Requests temporary SSH password access (writes /var/log/ssh-requests).

          Arguments:
            USERNAME    - The username requesting access
            REASON      - Reason for the access request (required)
            DURATION    - Duration in seconds (optional, default: 300)

          Examples:
            ncc ssh request-access fr4iser "Need to copy SSH keys"
            ncc ssh request-access john "Emergency server maintenance" 600
        '';
      }
    ])
  ];
}
