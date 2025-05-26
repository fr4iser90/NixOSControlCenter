{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.ssh-server-manager.request-access;
  ui = config.features.terminal-ui.api;
  notifications = config.features.ssh-server-manager.notifications;

  requestAccessScript = pkgs.writeScriptBin "ssh-request-access" ''
    #!${pkgs.bash}/bin/bash

    LOCKFILE="/tmp/ssh-request-access.lock"
    REQUESTS_DIR="/var/log/ssh-requests"
    
    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
      ${ui.messages.error "Another instance is running."}
      exit 1
    fi

    USER="$1"
    REASON="$2"
    DURATION="''${3:-300}"  # Default 5 minutes
    
    if [ -z "$USER" ] || [ -z "$REASON" ]; then
      ${ui.messages.error "Usage: ssh-request-access USERNAME REASON [DURATION_SECONDS]"}
      ${ui.messages.info "Example: ssh-request-access fr4iser 'Need to copy SSH keys' 300"}
      exit 1
    fi

    # Create requests directory if it doesn't exist
    sudo mkdir -p "$REQUESTS_DIR"
    sudo chmod 755 "$REQUESTS_DIR"

    # Generate unique request ID
    REQUEST_ID="$(date +%Y%m%d_%H%M%S)_$USER"
    REQUEST_FILE="$REQUESTS_DIR/$REQUEST_ID.json"

    ${ui.messages.loading "Processing SSH access request for $USER..."}

    # Create request record
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

    # Send notification to administrators
    ${if notifications.enable then ''
      MESSAGE="SSH Access Request from $USER
Request ID: $REQUEST_ID
Reason: $REASON
Duration: $DURATION seconds
Timestamp: $(date)

To approve: ssh-approve-request $REQUEST_ID
To deny: ssh-deny-request $REQUEST_ID \"reason\"
To view all: ssh-list-requests"
      
      ${if notifications.types.email.enable then ''
        echo "$MESSAGE" | ${pkgs.mailutils}/bin/mail -s "SSH Access Request: $USER" ${notifications.types.email.address}
      '' else ""}

      ${if notifications.types.desktop.enable then ''
        ${pkgs.libnotify}/bin/notify-send \
          -u critical \
          -t 0 \
          "SSH Access Request: $USER" \
          "Reason: $REASON\nID: $REQUEST_ID\nDuration: $DURATION sec"
      '' else ""}

      ${if notifications.types.webhook.enable then ''
        ${pkgs.curl}/bin/curl -X POST \
          -H 'Content-Type: application/json' \
          -d "{\"request_id\": \"$REQUEST_ID\", \"user\": \"$USER\", \"reason\": \"$REASON\", \"duration\": $DURATION, \"action\": \"request\"}" \
          ${notifications.types.webhook.url}
      '' else ""}
    '' else ""}

    ${ui.messages.success "SSH access request submitted successfully!"}
    ${ui.messages.info "Request ID: $REQUEST_ID"}
    ${ui.messages.info "Administrators have been notified. You will be contacted when the request is processed."}
    
    # Auto-cleanup old requests (older than 24 hours)
    find "$REQUESTS_DIR" -name "*.json" -mtime +1 -delete 2>/dev/null || true
  '';
in {
  options.features.ssh-server-manager.request-access = {
    enable = mkEnableOption "SSH access request functionality";
    
    defaultDuration = mkOption {
      type = types.int;
      default = 300;
      description = "Default duration (in seconds) for access requests";
    };

    maxDuration = mkOption {
      type = types.int;
      default = 3600;
      description = "Maximum allowed duration (in seconds) for access requests";
    };

    requireReason = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to require a reason for access requests";
    };
  };

  config = {
    environment.systemPackages = [ requestAccessScript ];

    features.command-center.commands = [
      {
        name = "ssh-request-access";
        description = "Request temporary SSH password access";
        category = "security";
        script = "${requestAccessScript}/bin/ssh-request-access";
        arguments = [ "USERNAME" "REASON" "[DURATION]" ];
        dependencies = [ "mailutils" "libnotify" "curl" ];
        shortHelp = "ssh-request-access USERNAME REASON [DURATION] - Request password access";
        longHelp = ''
          Requests temporary SSH password access, notifying administrators.
          
          Arguments:
            USERNAME    - The username requesting access
            REASON      - Reason for the access request (required)
            DURATION    - Duration in seconds (optional, default: 300)
          
          Examples:
            ssh-request-access fr4iser "Need to copy SSH keys"
            ssh-request-access john "Emergency server maintenance" 600
        '';
      }
    ];
  };
}
