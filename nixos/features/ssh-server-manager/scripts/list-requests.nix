{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.ssh-server-manager.list-requests;
  ui = config.core.cli-formatter.api;

  listRequestsScript = pkgs.writeScriptBin "ssh-list-requests" ''
    #!${pkgs.bash}/bin/bash

    REQUESTS_DIR="/var/log/ssh-requests"
    STATUS_FILTER="''${1:-all}"  # all, pending, approved, denied, expired
    
    if [ ! -d "$REQUESTS_DIR" ]; then
      ${ui.messages.info "No requests directory found. No SSH access requests have been made yet."}
      exit 0
    fi

    # Count requests by status
    TOTAL_COUNT=$(find "$REQUESTS_DIR" -name "*.json" | wc -l)
    PENDING_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -exec ${pkgs.jq}/bin/jq -r 'select(.status == "pending") | .id' {} \; 2>/dev/null | wc -l)
    APPROVED_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -exec ${pkgs.jq}/bin/jq -r 'select(.status == "approved") | .id' {} \; 2>/dev/null | wc -l)
    DENIED_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -exec ${pkgs.jq}/bin/jq -r 'select(.status == "denied") | .id' {} \; 2>/dev/null | wc -l)
    EXPIRED_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -exec ${pkgs.jq}/bin/jq -r 'select(.status == "expired") | .id' {} \; 2>/dev/null | wc -l)

    if [ "$TOTAL_COUNT" -eq 0 ]; then
      ${ui.messages.info "No SSH access requests found."}
      exit 0
    fi

    # Display header with counts
    echo "${ui.text.header "SSH Access Requests"}"
    echo "${ui.tables.keyValue "Total" "$TOTAL_COUNT"}"
    echo "${ui.tables.keyValue "Pending" "$PENDING_COUNT"}"
    echo "${ui.tables.keyValue "Approved" "$APPROVED_COUNT"}"
    echo "${ui.tables.keyValue "Denied" "$DENIED_COUNT"}"
    echo "${ui.tables.keyValue "Expired" "$EXPIRED_COUNT"}"
    echo ""

    # Usage information
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
      echo "Usage: ssh-list-requests [STATUS]"
      echo ""
      echo "STATUS options:"
      echo "  all      - Show all requests (default)"
      echo "  pending  - Show only pending requests"
      echo "  approved - Show only approved requests"
      echo "  denied   - Show only denied requests"
      echo "  expired  - Show only expired requests"
      echo ""
      echo "Examples:"
      echo "  ssh-list-requests"
      echo "  ssh-list-requests pending"
      echo "  ssh-list-requests approved"
      exit 0
    fi

    # Function to format duration
    format_duration() {
      local seconds=$1
      if [ $seconds -ge 3600 ]; then
        echo "$(($seconds / 3600))h $(($seconds % 3600 / 60))m"
      elif [ $seconds -ge 60 ]; then
        echo "$(($seconds / 60))m $(($seconds % 60))s"
      else
        echo "''${seconds}s"
      fi
    }

    # Function to format timestamp
    format_timestamp() {
      local timestamp="$1"
      if command -v date >/dev/null 2>&1; then
        date -d "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp"
      else
        echo "$timestamp"
      fi
    }

    # Function to get status color
    get_status_color() {
      case "$1" in
        "pending") echo "yellow" ;;
        "approved") echo "green" ;;
        "denied") echo "red" ;;
        "expired") echo "gray" ;;
        *) echo "white" ;;
      esac
    }

    # Display requests
    echo "Filtering by status: $STATUS_FILTER"
    echo ""

    # Create temporary file for sorted output
    TEMP_FILE=$(mktemp)
    
    # Process all request files
    for request_file in "$REQUESTS_DIR"/*.json; do
      if [ -f "$request_file" ]; then
        # Extract request data
        REQUEST_DATA=$(${pkgs.jq}/bin/jq -r '
          [.id, .user, .reason, .status, .timestamp, .duration, .approver // "", .denier // "", .deny_reason // ""] | @tsv
        ' "$request_file" 2>/dev/null)
        
        if [ -n "$REQUEST_DATA" ]; then
          echo "$REQUEST_DATA" >> "$TEMP_FILE"
        fi
      fi
    done

    # Sort by timestamp (newest first) and filter by status
    {
      while IFS=$'\t' read -r id user reason status timestamp duration approver denier deny_reason; do
        # Apply status filter
        if [ "$STATUS_FILTER" = "all" ] || [ "$status" = "$STATUS_FILTER" ]; then
          # Format the output
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "Request ID: $id"
          echo "User: $user"
          echo "Status: $status"
          echo "Reason: $reason"
          echo "Requested: $(format_timestamp "$timestamp")"
          echo "Duration: $(format_duration "$duration")"
          
          case "$status" in
            "approved")
              echo "Approved by: $approver"
              ;;
            "denied")
              echo "Denied by: $denier"
              echo "Denial reason: $deny_reason"
              ;;
            "pending")
              echo ""
              echo "Actions:"
              echo "  Approve: ssh-approve-request $id"
              echo "  Deny:    ssh-deny-request $id \"reason\""
              ;;
          esac
          echo ""
        fi
      done
    } < <(sort -t$'\t' -k5 -r "$TEMP_FILE")

    # Cleanup
    rm -f "$TEMP_FILE"

    # Show quick actions for pending requests
    if [ "$PENDING_COUNT" -gt 0 ] && [ "$STATUS_FILTER" = "all" ] || [ "$STATUS_FILTER" = "pending" ]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "Quick Actions:"
      echo "  View pending only: ssh-list-requests pending"
      echo "  Approve request:   ssh-approve-request REQUEST_ID"
      echo "  Deny request:      ssh-deny-request REQUEST_ID \"reason\""
      echo ""
    fi
  '';

  cleanupRequestsScript = pkgs.writeScriptBin "ssh-cleanup-requests" ''
    #!${pkgs.bash}/bin/bash

    REQUESTS_DIR="/var/log/ssh-requests"
    DAYS_OLD="''${1:-7}"  # Default to 7 days
    
    if [ ! -d "$REQUESTS_DIR" ]; then
      ${ui.messages.info "No requests directory found."}
      exit 0
    fi

    ${ui.messages.loading "Cleaning up SSH requests older than $DAYS_OLD days..."}
    
    # Count files before cleanup
    BEFORE_COUNT=$(find "$REQUESTS_DIR" -name "*.json" | wc -l)
    
    # Remove old request files
    REMOVED_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -mtime +$DAYS_OLD -delete -print | wc -l)
    
    AFTER_COUNT=$(find "$REQUESTS_DIR" -name "*.json" | wc -l)
    
    ${ui.messages.success "Cleanup completed"}
    ${ui.messages.info "Removed: $REMOVED_COUNT requests"}
    ${ui.messages.info "Remaining: $AFTER_COUNT requests"}
  '';
in {
  options.features.ssh-server-manager.list-requests = {
    enable = mkEnableOption "SSH request listing functionality";
    
    defaultCleanupDays = mkOption {
      type = types.int;
      default = 7;
      description = "Default number of days after which to clean up old requests";
    };

    maxDisplayRequests = mkOption {
      type = types.int;
      default = 50;
      description = "Maximum number of requests to display at once";
    };
  };

  config = {
    environment.systemPackages = [ listRequestsScript cleanupRequestsScript ];

    core.command-center.commands = [
      {
        name = "ssh-list-requests";
        description = "List SSH access requests";
        category = "security";
        script = "${listRequestsScript}/bin/ssh-list-requests";
        arguments = [ "[STATUS]" ];
        dependencies = [ "jq" ];
        shortHelp = "ssh-list-requests [STATUS] - List access requests";
        longHelp = ''
          Lists SSH access requests with optional status filtering.
          
          Arguments:
            STATUS  - Filter by status: all, pending, approved, denied, expired (optional)
          
          Examples:
            ssh-list-requests           # Show all requests
            ssh-list-requests pending   # Show only pending requests
            ssh-list-requests approved  # Show only approved requests
        '';
      }
      {
        name = "ssh-cleanup-requests";
        description = "Clean up old SSH access requests";
        category = "security";
        script = "${cleanupRequestsScript}/bin/ssh-cleanup-requests";
        arguments = [ "[DAYS]" ];
        dependencies = [ ];
        shortHelp = "ssh-cleanup-requests [DAYS] - Clean up old requests";
        longHelp = ''
          Removes SSH access request files older than specified days.
          
          Arguments:
            DAYS  - Number of days (optional, default: 7)
          
          Examples:
            ssh-cleanup-requests     # Clean up requests older than 7 days
            ssh-cleanup-requests 30  # Clean up requests older than 30 days
        '';
      }
    ];
  };
}
