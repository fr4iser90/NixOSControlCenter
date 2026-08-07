{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";
in
  pkgs.writeScriptBin "build" ''
    #!${pkgs.bash}/bin/bash

    trap '${ui.messages.error "Operation cancelled"}; exit 0' INT

    if [ $# -eq 0 ]; then
      ${ui.messages.info "Usage: build <command> [options]"}
      ${ui.messages.info "Commands: switch, boot, test, build"}
      ${ui.messages.info "Options: --force (skip checks)  --verbose (preflight details)"}
      exit 1
    fi

    FORCE=false
    VERBOSE=false
    REBUILD_ARGS=()
    for arg in "$@"; do
      case "$arg" in
        --force) FORCE=true ;;
        --verbose|-v) VERBOSE=true ;;
        *) REBUILD_ARGS+=("$arg") ;;
      esac
    done

    if [ "$FORCE" = true ]; then
      ${ui.badges.warning "Bypassing preflight checks"}
      exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild "''${REBUILD_ARGS[@]}"
    fi

    if [ "$VERBOSE" = true ]; then
      export NCC_PREFLIGHT_VERBOSE=1
    else
      export NCC_PREFLIGHT_VERBOSE=0
    fi

    ${ui.text.header "Preflight"}

    checks_failed=0

    ${ui.badges.info "CPU"}
    if ! prebuild-check-cpu; then
      ${ui.badges.error "CPU: check failed"}
      checks_failed=1
    fi

    ${ui.badges.info "GPU"}
    if ! prebuild-check-gpu; then
      ${ui.badges.error "GPU: check failed"}
      checks_failed=1
    fi

    ${ui.badges.info "Memory"}
    if ! prebuild-check-memory; then
      ${ui.badges.error "Memory: check failed"}
      checks_failed=1
    fi

    ${ui.badges.info "Users"}
    if ! prebuild-check-users; then
      ${ui.badges.error "Users: check failed"}
      checks_failed=1
    fi

    if [ "$checks_failed" -eq 1 ]; then
      ${ui.badges.error "Preflight failed"}
      printf "Continue with build anyway? [y/N] "
      read -r response || response=""
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        ${ui.badges.error "Build aborted"}
        exit 1
      fi
      ${ui.badges.warning "Continuing despite preflight failures"}
    else
      ${ui.badges.success "Preflight passed"}
    fi

    ${ui.text.header "Build"}
    ${ui.badges.info "nixos-rebuild"}
    if [ "''${#REBUILD_ARGS[@]}" -gt 0 ]; then
      echo "  args: ''${REBUILD_ARGS[*]}"
    fi

    build_log=$(mktemp)
    trap 'rm -f "$build_log"' EXIT

    set +e
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild "''${REBUILD_ARGS[@]}" 2>&1 | tee "$build_log"
    rebuild_rc=''${PIPESTATUS[0]}
    set -e

    if [ "$rebuild_rc" -eq 0 ]; then
      ${ui.badges.success "Build successful"}
      exit 0
    fi

    ${ui.badges.error "Build failed"}

    if grep -qiE 'unfree license|allowUnfree|NIXPKGS_ALLOW_UNFREE' "$build_log"; then
      ${ui.badges.warning "Unfree package blocked the build (e.g. zoom, steam)"}
      ${ui.messages.info "Flag: system-manager.allowUnfree (via getModuleConfig)"}
      ${ui.messages.info "Fix:  sudo ncc system allow-unfree"}
      ${ui.messages.info "Or:   sudo ncc system allow-unfree --rebuild"}
    fi

    exit "$rebuild_rc"
  ''
