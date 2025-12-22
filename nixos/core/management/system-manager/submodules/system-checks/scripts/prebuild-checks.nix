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
      exit 0
    else
      ${ui.badges.error "Build failed!"}
      exit 1
    fi
  ''
