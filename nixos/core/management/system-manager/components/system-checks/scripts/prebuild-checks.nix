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
      ${ui.messages.info "Options: --force (skip checks)  --verbose (preflight + rebuild log)"}
      ${ui.messages.info "Next: ncc system build switch"}
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

    # Parent update -v → NCC_CLI_VERBOSE=1 (preserved through sudo)
    if [ -n "''${NCC_CLI_VERBOSE:-}" ]; then
      VERBOSE=true
    fi

    NESTED=false
    if [ -n "''${NCC_CLI_NESTED:-}" ]; then
      NESTED=true
    fi

    if [ "$NESTED" != true ]; then
      ${ui.text.header "NixOS Build"}
    fi

    if [ "$FORCE" = true ]; then
      ${ui.badges.warning "Bypassing preflight checks"}
      exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild "''${REBUILD_ARGS[@]}"
    fi

    if [ "$VERBOSE" = true ]; then
      export NCC_PREFLIGHT_VERBOSE=1
    else
      export NCC_PREFLIGHT_VERBOSE=0
    fi

    checks_failed=0
    preflight_log=$(mktemp /tmp/ncc-preflight.XXXXXX.log)

    run_check() {
      local name="$1"
      shift
      if [ "$VERBOSE" = true ]; then
        if ! "$@"; then
          checks_failed=1
        fi
      else
        if ! "$@" >>"$preflight_log" 2>&1; then
          checks_failed=1
          cat "$preflight_log"
        fi
      fi
    }

    run_check platform prebuild-check-platform
    run_check cpu prebuild-check-cpu
    run_check gpu prebuild-check-gpu
    run_check memory prebuild-check-memory
    run_check users prebuild-check-users
    rm -f "$preflight_log"

    if [ "$checks_failed" -eq 1 ]; then
      ${ui.badges.error "Preflight"}
      printf "Continue with build anyway? [y/N] "
      read -r response || response=""
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        ${ui.badges.error "Build aborted"}
        ${ui.messages.info "Next: fix the failing checks, or re-run with --force"}
        exit 1
      fi
      ${ui.badges.warning "Continuing despite preflight failures"}
    else
      ${ui.badges.success "Preflight"}
    fi

    ${ui.messages.loading "Building…"}
    if [ "$VERBOSE" = true ] && [ "''${#REBUILD_ARGS[@]}" -gt 0 ]; then
      ${ui.messages.info "Rebuild args:"}
      printf '  %s\n' "''${REBUILD_ARGS[*]}"
    fi

    build_log=$(mktemp /tmp/ncc-build.XXXXXX.log)
    trap 'rm -f "$build_log"' EXIT

    set +e
    if [ "$VERBOSE" = true ]; then
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild "''${REBUILD_ARGS[@]}" 2>&1 | tee "$build_log"
      rebuild_rc=''${PIPESTATUS[0]}
    else
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild "''${REBUILD_ARGS[@]}" >"$build_log" 2>&1
      rebuild_rc=$?
    fi
    set -e

    if [ "$rebuild_rc" -eq 0 ]; then
      ${ui.badges.success "Switch"}
      if [ "$NESTED" != true ]; then
        ${ui.badges.success "Build complete"}
        if [ "$VERBOSE" = true ]; then
          ${ui.messages.info "Next: ncc system report   # optional full report"}
        fi
      fi
      exit 0
    fi

    ${ui.badges.error "Switch"}
    echo ""
    echo "======== COPYABLE ERROR (start) ========"
    if grep -q 'error:' "$build_log" 2>/dev/null; then
      awk '/error:/{p=1} p{print; c++; if(c>=40) exit}' "$build_log"
    else
      tail -n 50 "$build_log"
    fi
    echo "======== COPYABLE ERROR (end) ========"
    fail_log="/tmp/ncc-build-failed.log"
    cp -f "$build_log" "$fail_log" 2>/dev/null || true
    ${ui.messages.info "Full log: $fail_log"}

    if grep -qiE 'unfree license|allowUnfree|NIXPKGS_ALLOW_UNFREE' "$build_log"; then
      ${ui.badges.warning "Unfree package blocked the build (e.g. zoom, steam)"}
      ${ui.messages.info "Next: sudo ncc system allow-unfree"}
    elif grep -qiE 'system\.platform is unset|system\.platform is missing|currentSystem' "$build_log"; then
      ${ui.badges.warning "Platform unresolved"}
      ${ui.messages.info "Next: sudo ncc system update  (heals system.platform)"}
    else
      ${ui.messages.info "Next: fix the error above, then: ncc system build switch"}
    fi

    exit "$rebuild_rc"
  ''
