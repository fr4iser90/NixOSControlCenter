{ config, lib, pkgs, ... }:

with lib;

let
  cfg = systemConfig.modules.security.ssh-server.approve-request;
  ui = getModuleApi "cli-formatter";
  notifications = systemConfig.modules.security.ssh-server.notifications;
  backupHelpers = import ../../lib/backup-helpers.nix { inherit pkgs lib; };

  approveRequestScript = pkgs.writeScriptBin "ssh-approve-request" ''
    #!${pkgs.bash}/bin/bash

    LOCKFILE="/tmp/ssh-approve-request.lock"
    REQUESTS_DIR="/var/log/ssh-requests"
    
    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
      ${ui.messages.error "Another instance is running."}
      exit 1
    fi

    REQUEST_ID="$1"
    CUSTOM_DURATION="$2"
    
    if [ -z "$REQUEST_ID" ]; then
      ${ui.messages.error "Usage: ssh-approve-request REQUEST_ID [CUSTOM_DURATION]"}
      ${ui.messages.info "Example: ssh-approve-request 20250126_101530_fr4iser 600"}
      ${ui.messages.info "Use 'ssh-list-requests' to see pending requests"}
      exit 1
    fi

    REQUEST_FILE="$REQUESTS_DIR/$REQUEST_ID.json"
    
    if [ ! -f "$REQUEST_FILE" ]; then
      ${ui.messages.error "Request not found: $REQUEST_ID"}
      ${ui.messages.info "Use 'ssh-list-requests' to see available requests"}
      exit 1
    fi

    # Parse request details
    USER=$(${pkgs.jq}/bin/jq -r '.user' "$REQUEST_FILE")
    REASON=$(${pkgs.jq}/bin/jq -r '.reason' "$REQUEST_FILE")
    ORIGINAL_DURATION=$(${pkgs.jq}/bin/jq -r '.duration' "$REQUEST_FILE")
    STATUS=$(${pkgs.jq}/bin/jq -r '.status' "$REQUEST_FILE")
    
    # Use custom duration if provided, otherwise use original
    DURATION=''${CUSTOM_DURATION:-$ORIGINAL_DURATION}
    
    if [ "$STATUS" != "pending" ]; then
      ${ui.messages.error "Request $REQUEST_ID is not pending (status: $STATUS)"}
      exit 1
    fi

    ${ui.messages.loading "Approving SSH access request for $USER..."}
    ${ui.messages.info "Request ID: $REQUEST_ID"}
    ${ui.messages.info "Reason: $REASON"}
    ${ui.messages.info "Duration: $DURATION seconds"}

    # Update request status
    ${pkgs.jq}/bin/jq --arg status "approved" \
                      --arg approver "$USER" \
                      --arg approved_at "$(date -Iseconds)" \
                      --argjson final_duration "$DURATION" \
                      '.status = $status | .approver = $approver | .approved_at = $approved_at | .final_duration = $final_duration' \
                      "$REQUEST_FILE" > "$REQUEST_FILE.tmp" && mv "$REQUEST_FILE.tmp" "$REQUEST_FILE"

    # Enable password authentication temporarily
    ${ui.messages.info "Enabling SSH password authentication for $DURATION seconds..."}
    
    # Backup current SSH config using centralized backup helper
    ${backupHelpers.backupSSHConfig "/etc/ssh/sshd_config"} >/dev/null 2>&1 || true
    
    # Enable password authentication
    if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
      
      if [ $? -eq 0 ]; then
        ${ui.messages.success "SSH password authentication enabled successfully"}
      else
        ${ui.messages.error "Failed to restart SSH service"}
        exit 1
      fi
    else
      ${ui.messages.info "Password authentication already enabled"}
    fi

    # Send approval notification
    ${if notifications.enable then ''
      APPROVAL_MESSAGE="SSH Access Request APPROVED
Request ID: $REQUEST_ID
User: $USER
Reason: $REASON
Duration: $DURATION seconds
Approved by: $(whoami)
Approved at: $(date)

Password authentication is now enabled for $DURATION seconds."
      
      ${if notifications.types.email.enable then ''
        echo "$APPROVAL_MESSAGE" | ${pkgs.mailutils}/bin/mail -s "SSH Access APPROVED: $USER" ${notifications.types.email.address}
      '' else ""}

      ${if notifications.types.desktop.enable then ''
        ${pkgs.libnotify}/bin/notify-send \
          -u normal \
          "SSH Access APPROVED: $USER" \
          "Duration: $DURATION sec\nReason: $REASON"
      '' else ""}

      ${if notifications.types.webhook.enable then ''
        ${pkgs.curl}/bin/curl -X POST \
          -H 'Content-Type: application/json' \
          -d "{\"request_id\": \"$REQUEST_ID\", \"user\": \"$USER\", \"reason\": \"$REASON\", \"duration\": $DURATION, \"action\": \"approved\", \"approver\": \"$(whoami)\"}" \
          ${notifications.types.webhook.url}
      '' else ""}
    '' else ""}

    ${ui.messages.success "Request $REQUEST_ID approved successfully!"}
    ${ui.messages.info "Password authentication enabled for $USER for $DURATION seconds"}
    
    # Set up timer to disable access
    (
      sleep $DURATION
      
      # Restore original SSH config
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
      
      # Update request status to expired
      ${pkgs.jq}/bin/jq --arg status "expired" \
                        --arg expired_at "$(date -Iseconds)" \
                        '.status = $status | .expired_at = $expired_at' \
                        "$REQUEST_FILE" > "$REQUEST_FILE.tmp" && mv "$REQUEST_FILE.tmp" "$REQUEST_FILE"
      
      ${ui.messages.info "SSH password authentication disabled after $DURATION seconds for request $REQUEST_ID"}
      
      # Send expiration notification
      ${if notifications.enable then ''
        EXPIRY_MESSAGE="SSH Access EXPIRED
Request ID: $REQUEST_ID
User: $USER
Password authentication has been disabled."
        
        ${if notifications.types.desktop.enable then ''
          ${pkgs.libnotify}/bin/notify-send \
            -u normal \
            "SSH Access EXPIRED: $USER" \
            "Request ID: $REQUEST_ID"
        '' else ""}
      '' else ""}
    ) &
    
    ${ui.messages.info "Auto-disable timer set for $DURATION seconds"}
  '';

  denyRequestScript = pkgs.writeScriptBin "ssh-deny-request" ''
    #!${pkgs.bash}/bin/bash

    REQUESTS_DIR="/var/log/ssh-requests"
    REQUEST_ID="$1"
    DENY_REASON="$2"
    
    if [ -z "$REQUEST_ID" ] || [ -z "$DENY_REASON" ]; then
      ${ui.messages.error "Usage: ssh-deny-request REQUEST_ID REASON"}
      ${ui.messages.info "Example: ssh-deny-request 20250126_101530_fr4iser 'Use VPN instead'"}
      exit 1
    fi

    REQUEST_FILE="$REQUESTS_DIR/$REQUEST_ID.json"
    
    if [ ! -f "$REQUEST_FILE" ]; then
      ${ui.messages.error "Request not found: $REQUEST_ID"}
      exit 1
    fi

    # Parse request details
    USER=$(${pkgs.jq}/bin/jq -r '.user' "$REQUEST_FILE")
    REASON=$(${pkgs.jq}/bin/jq -r '.reason' "$REQUEST_FILE")
    STATUS=$(${pkgs.jq}/bin/jq -r '.status' "$REQUEST_FILE")
    
    if [ "$STATUS" != "pending" ]; then
      ${ui.messages.error "Request $REQUEST_ID is not pending (status: $STATUS)"}
      exit 1
    fi

    # Update request status
    ${pkgs.jq}/bin/jq --arg status "denied" \
                      --arg denier "$(whoami)" \
                      --arg denied_at "$(date -Iseconds)" \
                      --arg deny_reason "$DENY_REASON" \
                      '.status = $status | .denier = $denier | .denied_at = $denied_at | .deny_reason = $deny_reason' \
                      "$REQUEST_FILE" > "$REQUEST_FILE.tmp" && mv "$REQUEST_FILE.tmp" "$REQUEST_FILE"

    # Send denial notification
    ${if notifications.enable then ''
      DENIAL_MESSAGE="SSH Access Request DENIED
Request ID: $REQUEST_ID
User: $USER
Original Reason: $REASON
Denial Reason: $DENY_REASON
Denied by: $(whoami)
Denied at: $(date)"
      
      ${if notifications.types.email.enable then ''
        echo "$DENIAL_MESSAGE" | ${pkgs.mailutils}/bin/mail -s "SSH Access DENIED: $USER" ${notifications.types.email.address}
      '' else ""}

      ${if notifications.types.desktop.enable then ''
        ${pkgs.libnotify}/bin/notify-send \
          -u normal \
          "SSH Access DENIED: $USER" \
          "Reason: $DENY_REASON"
      '' else ""}

      ${if notifications.types.webhook.enable then ''
        ${pkgs.curl}/bin/curl -X POST \
          -H 'Content-Type: application/json' \
          -d "{\"request_id\": \"$REQUEST_ID\", \"user\": \"$USER\", \"reason\": \"$REASON\", \"action\": \"denied\", \"deny_reason\": \"$DENY_REASON\", \"denier\": \"$(whoami)\"}" \
          ${notifications.types.webhook.url}
      '' else ""}
    '' else ""}

    ${ui.messages.success "Request $REQUEST_ID denied successfully"}
    ${ui.messages.info "User: $USER"}
    ${ui.messages.info "Denial reason: $DENY_REASON"}
  '';
in {
  options.modules.security.ssh-server.approve-request = {
    enable = mkEnableOption "SSH request approval functionality";
    
    maxDuration = mkOption {
      type = types.int;
      default = 3600;
      description = "Maximum allowed duration for approved requests";
    };

    requireApprovalReason = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to require a reason when approving requests";
    };
  };

  config = {
    environment.systemPackages = [ approveRequestScript denyRequestScript ];

    config = lib.mkMerge [
      cliRegistry.registerCommandsFor "ssh-server-approve-request" [
      {
        name = "ssh-approve-request";
        description = "Approve SSH access request";
        category = "security";
        script = "${approveRequestScript}/bin/ssh-approve-request";
        arguments = [ "REQUEST_ID" "[DURATION]" ];
        dependencies = [ "jq" "mailutils" "libnotify" "curl" ];
        shortHelp = "ssh-approve-request REQUEST_ID [DURATION] - Approve access request";
        longHelp = ''
          Approves an SSH access request and enables password authentication.
          
          Arguments:
            REQUEST_ID  - The request ID to approve
            DURATION    - Custom duration in seconds (optional)
          
          Examples:
            ssh-approve-request 20250126_101530_fr4iser
            ssh-approve-request 20250126_101530_fr4iser 600
        '';
      }
      {
        name = "ssh-deny-request";
        description = "Deny SSH access request";
        category = "security";
        script = "${denyRequestScript}/bin/ssh-deny-request";
        arguments = [ "REQUEST_ID" "REASON" ];
        dependencies = [ "jq" "mailutils" "libnotify" "curl" ];
        shortHelp = "ssh-deny-request REQUEST_ID REASON - Deny access request";
        longHelp = ''
          Denies an SSH access request with a reason.
          
          Arguments:
            REQUEST_ID  - The request ID to deny
            REASON      - Reason for denial (required)
          
          Examples:
            ssh-deny-request 20250126_101530_fr4iser "Use VPN instead"
            ssh-deny-request 20250126_101530_fr4iser "Security policy violation"
        '';
      }
      ])
    ];
  };
}
