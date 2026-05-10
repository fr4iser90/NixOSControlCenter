{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cfg = getModuleConfig "system-checks";
  prebuildCfg = cfg.prebuild or {};
  ui = getModuleApi "cli-formatter";
in
  pkgs.writeScriptBin "build" ''
    #!${pkgs.bash}/bin/bash

    # Trap for CTRL+C
    trap '${ui.messages.error "Operation cancelled"}; exit 0' INT

    # Show usage if no arguments
    if [ $# -eq 0 ]; then
      ${ui.messages.info "Usage: build <command> [options]"}
      ${ui.messages.info "Commands: switch, boot, test, build"}
      ${ui.messages.info "Options: --force (Skip checks)"}
      exit 1
    fi

    # Check for --force flag
    if [[ " $* " =~ " --force " ]]; then
      ${ui.messages.warning "Bypassing preflight checks!"}
      args=$(echo "$@" | sed 's/--force//')
      exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild $args
    fi

    ${ui.messages.loading "Running system checks..."}

    # Initialize check status
    checks_failed=0

    # Run CPU check
    ${ui.badges.info "Running CPU check..."}
    if ! prebuild-check-cpu; then
      ${ui.badges.error "CPU check failed!"}
      checks_failed=1
    fi

    # Run GPU check
    ${ui.badges.info "Running GPU check..."}
    if ! prebuild-check-gpu; then
      ${ui.badges.error "GPU check failed!"}
      checks_failed=1
    fi

    # Run Memory check
    ${ui.badges.info "Running Memory check..."}
    if ! prebuild-check-memory; then
      ${ui.badges.error "Memory check failed!"}
      checks_failed=1
    fi

    # Run User check
    ${ui.badges.info "Running User check..."}
    if ! prebuild-check-users; then
      ${ui.badges.error "User check failed!"}
      checks_failed=1
    fi

    # If any checks failed, ask for confirmation
    if [ $checks_failed -eq 1 ]; then
      ${ui.badges.warning "Some checks failed! Continue anyway?"}
      read -p "Continue with build? [y/N] " response
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        ${ui.badges.error "Build aborted."}
        exit 1
      fi
    else
      ${ui.badges.success "All checks passed!"}
    fi

    ${ui.badges.info "Running nixos-rebuild..."}

    if ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"; then
      ${ui.badges.success "Build successful!"}
      
      # Post-rebuild: Re-apply saved passwords to shadow.
      # The activation step in nixos-rebuild may write "!" (locked) for users
      # when builtins.pathExists fails in flake eval. This safety net ensures
      # login works regardless of Nix evaluation quirks.
      PASSWORD_DIR="/etc/nixos/secrets/passwords"
      if [ -d "$PASSWORD_DIR" ]; then
        for user_dir in "$PASSWORD_DIR"/*; do
          [ -e "$user_dir" ] || continue
          user=$(basename "$user_dir")
          HASH_FILE="$user_dir/.hashedPassword"
          if [ -f "$HASH_FILE" ]; then
            SAVED_HASH=$(cat "$HASH_FILE")
            if [ -n "$SAVED_HASH" ]; then
              SHADOW_HASH=$(getent shadow "$user" 2>/dev/null | cut -d: -f2)
              if [ -z "$SHADOW_HASH" ] || [ "$SHADOW_HASH" = "!" ] || [ "$SHADOW_HASH" != "$SAVED_HASH" ]; then
                if echo "$user:$SAVED_HASH" | ${pkgs.shadow}/bin/chpasswd -e 2>/dev/null; then
                  ${ui.badges.success "Password re-applied for $user"}
                fi
              fi
            fi
          fi
        done
      fi
      
      exit 0
    else
      ${ui.badges.error "Build failed!"}
      exit 1
    fi
  ''
