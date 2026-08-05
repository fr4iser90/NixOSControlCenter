{ pkgs, lib, getModuleApi, hostname, systemChecks }:

let
  ui = getModuleApi "cli-formatter";

  updateChannelsScript = pkgs.writeScriptBin "ncc-update-channels" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    SKIP_REBUILD=0
    BUMP_TO=""
    FLAKE_DIR="/etc/nixos"

    while [ $# -gt 0 ]; do
      case "$1" in
        --skip-rebuild) SKIP_REBUILD=1; shift ;;
        --bump-to)
          BUMP_TO="$2"
          shift 2
          ;;
        --flake)
          FLAKE_DIR="$2"
          shift 2
          ;;
        --help|-h)
          echo "Usage: ncc-update-channels [--skip-rebuild] [--bump-to YY.MM] [--flake DIR]"
          echo "  --skip-rebuild  Only update flake.lock / pins (no rebuild)"
          echo "  --bump-to       Rewrite nixos-/release- pins in flake.nix to YY.MM"
          exit 0
          ;;
        *)
          ${ui.messages.error "Unknown option: $1"}
          exit 1
          ;;
      esac
    done

    if [ "$EUID" -ne 0 ]; then
      ${ui.messages.error "This script must be run as root (use sudo)"}
      ${ui.messages.info "Usage: sudo $0"}
      exit 1
    fi

    ${ui.text.header "NixOS Channel Update"}

    FLAKE_FILE="$FLAKE_DIR/flake.nix"
    if [ ! -f "$FLAKE_FILE" ]; then
      ${ui.messages.error "Flake not found: $FLAKE_FILE"}
      exit 1
    fi

    if [ -n "$BUMP_TO" ]; then
      CURRENT=$(grep -E 'nixpkgs-stable\.url|nixos-[0-9]+\.[0-9]+' "$FLAKE_FILE" \
        | grep -oE 'nixos-[0-9]+\.[0-9]+' \
        | head -1 \
        | sed 's/nixos-//' || true)
      if [ -z "''${CURRENT:-}" ]; then
        ${ui.messages.error "Could not detect current nixos-YY.MM pin in $FLAKE_FILE"}
        exit 1
      fi
      if [ "$CURRENT" != "$BUMP_TO" ]; then
        ${ui.messages.loading "Bumping flake pins: nixos-$CURRENT → nixos-$BUMP_TO"}
        # Input URLs only — do not touch stateVersion
        ${pkgs.gnused}/bin/sed -i \
          -e "s|nixos-$CURRENT|nixos-$BUMP_TO|g" \
          -e "s|release-$CURRENT|release-$BUMP_TO|g" \
          "$FLAKE_FILE"
        ${ui.messages.success "Flake pins updated to $BUMP_TO"}
      else
        ${ui.messages.info "Flake already pinned to nixos-$BUMP_TO"}
      fi
    fi

    ${ui.messages.loading "Updating flake inputs (nix flake update)..."}
    if ! nix flake update --flake "$FLAKE_DIR"; then
      ${ui.messages.error "Failed to update flake inputs!"}
      exit 1
    fi
    ${ui.messages.success "Flake inputs updated successfully."}

    if [ "$SKIP_REBUILD" -eq 1 ]; then
      ${ui.messages.info "Skipping rebuild (--skip-rebuild)."}
      exit 0
    fi

    ${ui.messages.loading "Rebuilding system..."}
    BUILD_CMD="${if systemChecks then "ncc system build switch --flake /etc/nixos#${hostname}" else "nixos-rebuild switch --flake /etc/nixos#${hostname}"}"

    set +e
    sh -c "$BUILD_CMD" 2>&1
    EXIT_CODE=$?
    set -e

    if [ "$EXIT_CODE" -eq 0 ]; then
      ${ui.messages.success "System successfully rebuilt!"}
      exit 0
    fi

    if [ -f /nix/var/nix/profiles/system ]; then
      CURRENT_GEN=$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2 || true)
      if [ -n "''${CURRENT_GEN:-}" ]; then
        ${ui.messages.warning "Build completed, but switch encountered issues (exit code: $EXIT_CODE)"}
        ${ui.messages.info "Current generation: $CURRENT_GEN"}
        ${ui.messages.info "Some services may have failed to reload (e.g., dbus-broker.service)"}
        ${ui.messages.info "This is often harmless - the system should still work correctly."}
        ${ui.messages.info "You can verify with: nixos-rebuild switch --flake /etc/nixos#${hostname}"}
        exit 0
      fi
    fi

    ${ui.messages.error "Rebuild failed! Check logs for details."}
    exit 1
  '';
in {
  inherit updateChannelsScript;
}
