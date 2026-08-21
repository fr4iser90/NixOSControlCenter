{ config, lib, pkgs, getModuleApi, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";

  listRequestsScript = pkgs.writeScriptBin "ssh-list-requests" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    REQUESTS_DIR="/var/log/ssh-requests"
    STATUS_FILTER="''${1:-all}"

    if [ "$STATUS_FILTER" = "--help" ] || [ "$STATUS_FILTER" = "-h" ]; then
      cat <<EOF
Usage: ncc ssh list-requests [STATUS]

STATUS: all (default), pending, approved, denied, expired
EOF
      exit 0
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "SSH access requests"}
    fi

    ${ui.messages.loading "Reading $REQUESTS_DIR…"}

    if [ ! -d "$REQUESTS_DIR" ]; then
      ${ui.messages.warning "No requests directory yet — none submitted"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc ssh request-access USER REASON"}
      fi
      exit 0
    fi

    TOTAL_COUNT=$(find "$REQUESTS_DIR" -name "*.json" 2>/dev/null | wc -l)
    PENDING_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -exec ${pkgs.jq}/bin/jq -r 'select(.status == "pending") | .id' {} \; 2>/dev/null | wc -l)
    APPROVED_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -exec ${pkgs.jq}/bin/jq -r 'select(.status == "approved") | .id' {} \; 2>/dev/null | wc -l)
    DENIED_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -exec ${pkgs.jq}/bin/jq -r 'select(.status == "denied") | .id' {} \; 2>/dev/null | wc -l)
    EXPIRED_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -exec ${pkgs.jq}/bin/jq -r 'select(.status == "expired") | .id' {} \; 2>/dev/null | wc -l)

    ${ui.tables.keyValue "Total" "$TOTAL_COUNT"}
    ${ui.tables.keyValue "Pending" "$PENDING_COUNT"}
    ${ui.tables.keyValue "Approved" "$APPROVED_COUNT"}
    ${ui.tables.keyValue "Denied" "$DENIED_COUNT"}
    ${ui.tables.keyValue "Expired" "$EXPIRED_COUNT"}
    ${ui.tables.keyValue "Filter" "$STATUS_FILTER"}

    if [ "$TOTAL_COUNT" -eq 0 ]; then
      ${ui.messages.warning "No SSH access requests found"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc ssh request-access USER REASON"}
      fi
      exit 0
    fi

    format_duration() {
      local seconds=$1
      if [ "$seconds" -ge 3600 ]; then
        echo "$((seconds / 3600))h $((seconds % 3600 / 60))m"
      elif [ "$seconds" -ge 60 ]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
      else
        echo "''${seconds}s"
      fi
    }

    format_timestamp() {
      local timestamp="$1"
      date -d "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp"
    }

    TEMP_FILE=$(mktemp)
    trap 'rm -f "$TEMP_FILE"' EXIT

    for request_file in "$REQUESTS_DIR"/*.json; do
      [ -f "$request_file" ] || continue
      REQUEST_DATA=$(${pkgs.jq}/bin/jq -r '
        [.id, .user, .reason, .status, .timestamp, .duration, .approver // "", .denier // "", .deny_reason // ""] | @tsv
      ' "$request_file" 2>/dev/null || true)
      if [ -n "$REQUEST_DATA" ]; then
        echo "$REQUEST_DATA" >> "$TEMP_FILE"
      fi
    done

    shown=0
    while IFS=$'\t' read -r id user reason status timestamp duration approver denier deny_reason; do
      if [ "$STATUS_FILTER" = "all" ] || [ "$status" = "$STATUS_FILTER" ]; then
        shown=1
        ${ui.text.separator "72"}
        ${ui.tables.keyValue "Request ID" "$id"}
        ${ui.tables.keyValue "User" "$user"}
        ${ui.tables.keyValue "Status" "$status"}
        ${ui.tables.keyValue "Reason" "$reason"}
        ${ui.tables.keyValue "Requested" ''$(format_timestamp "$timestamp")''}
        ${ui.tables.keyValue "Duration" ''$(format_duration "$duration")''}
        case "$status" in
          approved)
            ${ui.tables.keyValue "Approved by" "$approver"}
            ;;
          denied)
            ${ui.tables.keyValue "Denied by" "$denier"}
            ${ui.tables.keyValue "Denial reason" "$deny_reason"}
            ;;
          pending)
            ${ui.messages.info "Approve: ncc ssh approve-request $id"}
            ${ui.messages.info "Deny:    ncc ssh deny-request $id \"reason\""}
            ;;
        esac
      fi
    done < <(sort -t$'\t' -k5 -r "$TEMP_FILE" 2>/dev/null || true)

    if [ "$shown" -eq 0 ]; then
      ${ui.messages.warning "No requests matched filter: $STATUS_FILTER"}
    else
      ${ui.messages.success "SSH access requests listed"}
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      if [ "$PENDING_COUNT" -gt 0 ]; then
        ${ui.messages.info "Next: ncc ssh approve-request REQUEST_ID   or   ncc ssh list-requests pending"}
      else
        ${ui.messages.info "Next: ncc ssh request-access USER REASON"}
      fi
    fi
  '';

  cleanupRequestsScript = pkgs.writeScriptBin "ssh-cleanup-requests" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    REQUESTS_DIR="/var/log/ssh-requests"
    DAYS_OLD="''${1:-7}"

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "SSH cleanup-requests"}
    fi

    ${ui.messages.loading "Cleaning requests older than $DAYS_OLD days…"}

    if [ ! -d "$REQUESTS_DIR" ]; then
      ${ui.messages.warning "No requests directory found"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc ssh list-requests"}
      fi
      exit 0
    fi

    BEFORE_COUNT=$(find "$REQUESTS_DIR" -name "*.json" | wc -l)
    REMOVED_COUNT=$(find "$REQUESTS_DIR" -name "*.json" -mtime +"$DAYS_OLD" -delete -print | wc -l)
    AFTER_COUNT=$(find "$REQUESTS_DIR" -name "*.json" | wc -l)

    ${ui.tables.keyValue "Removed" "$REMOVED_COUNT"}
    ${ui.tables.keyValue "Remaining" "$AFTER_COUNT"}
    ${ui.tables.keyValue "Before" "$BEFORE_COUNT"}
    ${ui.messages.success "Cleanup completed"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc ssh list-requests"}
    fi
  '';
in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ listRequestsScript cleanupRequestsScript ];
    }
    (cliRegistry.registerCommandsFor "ssh-server-list-requests" [
      {
        name = "list-requests";
        parent = "ssh";
        domain = "ssh";
        description = "List SSH access requests";
        category = "security";
        script = "${listRequestsScript}/bin/ssh-list-requests";
        arguments = [ "[STATUS]" ];
        dependencies = [ "jq" ];
        shortHelp = "list-requests [STATUS] - List access requests";
        longHelp = ''
          Lists SSH access requests with optional status filtering.

          Examples:
            ncc ssh list-requests
            ncc ssh list-requests pending
            ncc ssh list-requests approved
        '';
      }
      {
        name = "cleanup-requests";
        parent = "ssh";
        domain = "ssh";
        description = "Clean up old SSH access requests";
        category = "security";
        script = "${cleanupRequestsScript}/bin/ssh-cleanup-requests";
        arguments = [ "[DAYS]" ];
        dependencies = [ ];
        shortHelp = "cleanup-requests [DAYS] - Clean up old requests";
        longHelp = ''
          Removes SSH access request files older than specified days.

          Examples:
            ncc ssh cleanup-requests
            ncc ssh cleanup-requests 30
        '';
      }
    ])
  ];
}
