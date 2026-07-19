# Remove leftover pre-v1 paths that the flake never loads.
# Canonical user config root is always: /etc/nixos/systemConfig
{ pkgs, lib, getModuleApi, backupHelpers, ... }:

let
  formatter = getModuleApi "cli-formatter";
in {
  cleanupLegacyConfigs = pkgs.writeShellScriptBin "ncc-cleanup-legacy-configs" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    NIXOS_CONFIG_DIR="''${NIXOS_CONFIG_DIR:-/etc/nixos}"
    LEGACY_DIR="$NIXOS_CONFIG_DIR/configs"
    CANONICAL_DIR="$NIXOS_CONFIG_DIR/systemConfig"
    VERBOSE=false

    for arg in "$@"; do
      case "$arg" in
        --verbose|--debug|-v) VERBOSE=true ;;
      esac
    done

    # Nothing to do
    if [ ! -d "$LEGACY_DIR" ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "No legacy configs/ directory found"}
      fi
      exit 0
    fi

    ${formatter.messages.warning "Legacy configs/ detected (flake only loads systemConfig/)"}

    # Rescue: rename if canonical root is missing
    if [ ! -d "$CANONICAL_DIR" ]; then
      ${formatter.messages.loading "Renaming configs/ → systemConfig/ (rescue)"}
      if mv "$LEGACY_DIR" "$CANONICAL_DIR" 2>/dev/null || sudo mv "$LEGACY_DIR" "$CANONICAL_DIR"; then
        ${formatter.messages.success "Moved legacy configs/ to systemConfig/"}
        exit 0
      else
        ${formatter.messages.error "Failed to rename configs/ to systemConfig/"}
        exit 1
      fi
    fi

    # Both exist: merge missing leaf configs into systemConfig, then delete legacy
    ${formatter.messages.loading "Merging missing files from configs/ into systemConfig/"}

    BACKUP_PATH=$(
      ${backupHelpers.backupDirectory "$LEGACY_DIR" "legacy-configs-cleanup"}
    )
    if [ -n "$BACKUP_PATH" ]; then
      ${formatter.messages.info "Legacy configs/ backed up to: $BACKUP_PATH"}
    else
      ${formatter.messages.warning "Could not back up configs/ — continuing with merge anyway"}
    fi

    MERGED=0
    SKIPPED_SAME=0
    SKIPPED_DIFF=0

    while IFS= read -r -d $'\0' legacy_file; do
      [ -z "$legacy_file" ] && continue
      rel="''${legacy_file#"$LEGACY_DIR"/}"
      target="$CANONICAL_DIR/$rel"

      if [ ! -e "$target" ]; then
        mkdir -p "$(dirname "$target")" 2>/dev/null || sudo mkdir -p "$(dirname "$target")"
        if cp "$legacy_file" "$target" 2>/dev/null || sudo cp "$legacy_file" "$target"; then
          MERGED=$((MERGED + 1))
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.info "Merged missing: $rel"}
          fi
        fi
      elif cmp -s "$legacy_file" "$target" 2>/dev/null; then
        SKIPPED_SAME=$((SKIPPED_SAME + 1))
      else
        # systemConfig is canonical — keep it, do not overwrite with legacy
        SKIPPED_DIFF=$((SKIPPED_DIFF + 1))
        ${formatter.messages.warning "Kept systemConfig version (differs from legacy): $rel"}
      fi
    done < <(find "$LEGACY_DIR" -type f -print0 2>/dev/null)

    ${formatter.messages.info "Legacy merge: $MERGED imported, $SKIPPED_SAME identical, $SKIPPED_DIFF conflicts kept as systemConfig"}

    ${formatter.messages.loading "Removing legacy configs/"}
    if rm -rf "$LEGACY_DIR" 2>/dev/null || sudo rm -rf "$LEGACY_DIR"; then
      ${formatter.messages.success "Removed legacy configs/ — only systemConfig/ remains"}
    else
      ${formatter.messages.error "Failed to remove legacy configs/"}
      exit 1
    fi
  '';
}
