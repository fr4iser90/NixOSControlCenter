{ config, lib, pkgs, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  smRoot = (getModuleMetadata "system-manager").path;
  backupHelpers = import "${smRoot}/lib/backup-helpers.nix" { inherit pkgs lib; };

  approveRequestScript = pkgs.writeScriptBin "ssh-approve-request" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    LOCKFILE="/tmp/ssh-approve-request.lock"
    REQUESTS_DIR="/var/log/ssh-requests"

    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
      ${ui.messages.error "Another instance is running."}
      exit 1
    fi

    REQUEST_ID="''${1:-}"
    CUSTOM_DURATION="''${2:-}"

    if [ -z "$REQUEST_ID" ]; then
      ${ui.messages.error "Usage: ncc ssh approve-request REQUEST_ID [CUSTOM_DURATION]"}
      ${ui.messages.info "Example: ncc ssh approve-request 20250126_101530_fr4iser 600"}
      ${ui.messages.info "Next: ncc ssh list-requests pending"}
      exit 1
    fi

    REQUEST_FILE="$REQUESTS_DIR/$REQUEST_ID.json"

    if [ ! -f "$REQUEST_FILE" ]; then
      ${ui.messages.error "Request not found: $REQUEST_ID"}
      ${ui.messages.info "Next: ncc ssh list-requests"}
      exit 1
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "SSH approve-request"}
    fi

    USER=$(${pkgs.jq}/bin/jq -r '.user' "$REQUEST_FILE")
    REASON=$(${pkgs.jq}/bin/jq -r '.reason' "$REQUEST_FILE")
    ORIGINAL_DURATION=$(${pkgs.jq}/bin/jq -r '.duration' "$REQUEST_FILE")
    STATUS=$(${pkgs.jq}/bin/jq -r '.status' "$REQUEST_FILE")
    DURATION=''${CUSTOM_DURATION:-$ORIGINAL_DURATION}

    if [ "$STATUS" != "pending" ]; then
      ${ui.messages.error "Request $REQUEST_ID is not pending (status: $STATUS)"}
      ${ui.messages.info "Next: ncc ssh list-requests pending"}
      exit 1
    fi

    ${ui.messages.loading "Approving SSH access request for $USER…"}
    ${ui.tables.keyValue "Request ID" "$REQUEST_ID"}
    ${ui.tables.keyValue "User" "$USER"}
    ${ui.tables.keyValue "Reason" "$REASON"}
    ${ui.tables.keyValue "Duration" "$DURATION seconds"}

    ${pkgs.jq}/bin/jq --arg status "approved" \
                      --arg approver "$(whoami)" \
                      --arg approved_at "$(date -Iseconds)" \
                      --argjson final_duration "$DURATION" \
                      '.status = $status | .approver = $approver | .approved_at = $approved_at | .final_duration = $final_duration' \
                      "$REQUEST_FILE" > "$REQUEST_FILE.tmp" && mv "$REQUEST_FILE.tmp" "$REQUEST_FILE"

    ${backupHelpers.backupSSHConfig "/etc/ssh/sshd_config"} >/dev/null 2>&1 || true

    if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
      if sudo systemctl restart sshd; then
        ${ui.messages.success "SSH password authentication enabled"}
      else
        ${ui.messages.error "Failed to restart SSH service"}
        exit 1
      fi
    else
      ${ui.messages.info "Password authentication already enabled"}
    fi

    (
      sleep "$DURATION"
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl restart sshd || true
      ${pkgs.jq}/bin/jq --arg status "expired" \
                        --arg expired_at "$(date -Iseconds)" \
                        '.status = $status | .expired_at = $expired_at' \
                        "$REQUEST_FILE" > "$REQUEST_FILE.tmp" && mv "$REQUEST_FILE.tmp" "$REQUEST_FILE"
      ${ui.messages.info "SSH password authentication disabled after $DURATION seconds for request $REQUEST_ID"}
    ) &

    ${ui.messages.success "Request $REQUEST_ID approved"}
    ${ui.messages.info "Auto-disable timer set for $DURATION seconds"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: connect as $USER with password, then ncc ssh list-requests"}
    fi
  '';

  denyRequestScript = pkgs.writeScriptBin "ssh-deny-request" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    REQUESTS_DIR="/var/log/ssh-requests"
    REQUEST_ID="''${1:-}"
    DENY_REASON="''${2:-}"

    if [ -z "$REQUEST_ID" ] || [ -z "$DENY_REASON" ]; then
      ${ui.messages.error "Usage: ncc ssh deny-request REQUEST_ID REASON"}
      ${ui.messages.info "Example: ncc ssh deny-request 20250126_101530_fr4iser 'Use VPN instead'"}
      exit 1
    fi

    REQUEST_FILE="$REQUESTS_DIR/$REQUEST_ID.json"

    if [ ! -f "$REQUEST_FILE" ]; then
      ${ui.messages.error "Request not found: $REQUEST_ID"}
      ${ui.messages.info "Next: ncc ssh list-requests"}
      exit 1
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "SSH deny-request"}
    fi

    USER=$(${pkgs.jq}/bin/jq -r '.user' "$REQUEST_FILE")
    REASON=$(${pkgs.jq}/bin/jq -r '.reason' "$REQUEST_FILE")
    STATUS=$(${pkgs.jq}/bin/jq -r '.status' "$REQUEST_FILE")

    if [ "$STATUS" != "pending" ]; then
      ${ui.messages.error "Request $REQUEST_ID is not pending (status: $STATUS)"}
      ${ui.messages.info "Next: ncc ssh list-requests pending"}
      exit 1
    fi

    ${ui.messages.loading "Denying SSH access request $REQUEST_ID…"}
    ${ui.tables.keyValue "User" "$USER"}
    ${ui.tables.keyValue "Original reason" "$REASON"}
    ${ui.tables.keyValue "Denial reason" "$DENY_REASON"}

    ${pkgs.jq}/bin/jq --arg status "denied" \
                      --arg denier "$(whoami)" \
                      --arg denied_at "$(date -Iseconds)" \
                      --arg deny_reason "$DENY_REASON" \
                      '.status = $status | .denier = $denier | .denied_at = $denied_at | .deny_reason = $deny_reason' \
                      "$REQUEST_FILE" > "$REQUEST_FILE.tmp" && mv "$REQUEST_FILE.tmp" "$REQUEST_FILE"

    ${ui.messages.success "Request $REQUEST_ID denied"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc ssh list-requests"}
    fi
  '';
in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ approveRequestScript denyRequestScript ];
    }
    (cliRegistry.registerCommandsFor "ssh-server-approve-request" [
      {
        name = "approve-request";
        parent = "ssh";
        domain = "ssh";
        description = "Approve SSH access request";
        category = "security";
        script = "${approveRequestScript}/bin/ssh-approve-request";
        arguments = [ "REQUEST_ID" "[DURATION]" ];
        dependencies = [ "jq" ];
        shortHelp = "approve-request REQUEST_ID [DURATION] - Approve access request";
        longHelp = ''
          Approves an SSH access request and enables password authentication.

          Examples:
            ncc ssh approve-request 20250126_101530_fr4iser
            ncc ssh approve-request 20250126_101530_fr4iser 600
        '';
      }
      {
        name = "deny-request";
        parent = "ssh";
        domain = "ssh";
        description = "Deny SSH access request";
        category = "security";
        script = "${denyRequestScript}/bin/ssh-deny-request";
        arguments = [ "REQUEST_ID" "REASON" ];
        dependencies = [ "jq" ];
        shortHelp = "deny-request REQUEST_ID REASON - Deny access request";
        longHelp = ''
          Denies an SSH access request with a reason.

          Examples:
            ncc ssh deny-request 20250126_101530_fr4iser "Use VPN instead"
        '';
      }
    ])
  ];
}
