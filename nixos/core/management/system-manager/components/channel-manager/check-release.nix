{ pkgs, lib, getModuleApi, channel }:

let
  ui = getModuleApi "cli-formatter";
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  configuredChannel = channel;

  # Exit codes for scripting / notify:
  #   0  = up to date (or informational-only for unstable)
  #  10 = newer stable NixOS release available
  #   1  = error
  checkReleaseScript = pkgs.writeScriptBin "ncc-check-release" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    FLAKE_FILE="''${NCC_FLAKE_FILE:-/etc/nixos/flake.nix}"
    CHANNEL="${configuredChannel}"
    QUIET=0
    JSON=0

    while [ $# -gt 0 ]; do
      case "$1" in
        --quiet|-q) QUIET=1; shift ;;
        --json) JSON=1; shift ;;
        --flake)
          FLAKE_FILE="$2"
          shift 2
          ;;
        --help|-h)
          echo "Usage: ncc system check-release [--quiet] [--json] [--flake PATH]"
          echo "Exit 0 = current, 10 = newer stable release available, 1 = error"
          exit 0
          ;;
        *)
          ${ui.messages.error "Unknown option: $1"}
          exit 1
          ;;
      esac
    done

    if [ ! -f "$FLAKE_FILE" ]; then
      ${ui.messages.error "Flake not found: $FLAKE_FILE"}
      exit 1
    fi

    CURRENT=$(grep -E 'nixpkgs-stable\.url|nixos-[0-9]+\.[0-9]+' "$FLAKE_FILE" \
      | grep -oE 'nixos-[0-9]+\.[0-9]+' \
      | head -1 \
      | sed 's/nixos-//' || true)

    if [ -z "''${CURRENT:-}" ]; then
      ${ui.messages.error "Could not detect current nixos-YY.MM pin in $FLAKE_FILE"}
      exit 1
    fi

    RUNNING=$(${pkgs.coreutils}/bin/cat /run/current-system/nixos-version 2>/dev/null || true)

    if [ "$QUIET" -eq 0 ] && [ "$JSON" -eq 0 ]; then
      ${ui.text.header "NixOS Release Check"}
      ${ui.messages.info "Configured channel: $CHANNEL"}
      ${ui.messages.info "Flake stable pin: nixos-$CURRENT"}
      if [ -n "''${RUNNING:-}" ]; then
        ${ui.messages.info "Running system: $RUNNING"}
      fi
      ${ui.messages.loading "Fetching latest NixOS stable branches..."}
    fi

    API_URL="https://api.github.com/repos/NixOS/nixpkgs/git/matching-refs/heads/nixos-"
    RAW=$(${curl} -fsSL "$API_URL" 2>/dev/null || true)

    if [ -z "''${RAW:-}" ]; then
      ${ui.messages.error "Failed to reach GitHub API for nixpkgs release branches"}
      exit 1
    fi

    LATEST=$(echo "$RAW" | ${jq} -r '
      [ .[]?.ref
        | sub("^refs/heads/nixos-"; "")
        | select(test("^[0-9]+\\.[0-9]+$"))
      ]
      | sort_by(split(".") | map(tonumber))
      | last // empty
    ')

    if [ -z "''${LATEST:-}" ]; then
      ${ui.messages.error "Could not determine latest nixos-YY.MM branch"}
      exit 1
    fi

    STATUS="current"
    EXIT=0
    if [ "$CURRENT" != "$LATEST" ]; then
      # numeric compare: only flag when upstream is newer
      NEWER=$(printf '%s\n%s\n' "$CURRENT" "$LATEST" | ${pkgs.coreutils}/bin/sort -V | ${pkgs.coreutils}/bin/tail -1)
      if [ "$NEWER" = "$LATEST" ]; then
        STATUS="update-available"
        EXIT=10
      fi
    fi

    if [ "$JSON" -eq 1 ]; then
      ${jq} -n \
        --arg channel "$CHANNEL" \
        --arg current "$CURRENT" \
        --arg latest "$LATEST" \
        --arg running "''${RUNNING:-}" \
        --arg status "$STATUS" \
        '{channel:$channel, current:$current, latest:$latest, running:$running, status:$status}'
      exit "$EXIT"
    fi

    if [ "$QUIET" -eq 0 ]; then
      ${ui.messages.info "Latest stable: nixos-$LATEST"}
      echo ""
      if [ "$STATUS" = "update-available" ]; then
        ${ui.messages.warning "Update available: nixos-$CURRENT → nixos-$LATEST"}
        ${ui.messages.info "Next steps:"}
        echo "  1. Bump flake inputs (nixpkgs-stable / home-manager-stable) to $LATEST"
        echo "  2. Review release notes: https://nixos.org/manual/nixos/stable/release-notes.html"
        echo "  3. Apply package updates: sudo ncc system update-channels"
        echo "     or: sudo ncc system update --channels"
      else
        ${ui.messages.success "Already on latest stable pin: nixos-$CURRENT"}
        if [ "$CHANNEL" = "unstable" ]; then
          ${ui.messages.info "Channel is unstable — run: sudo ncc system update-channels"}
        fi
      fi
    fi

    exit "$EXIT"
  '';
in {
  inherit checkReleaseScript;
}
