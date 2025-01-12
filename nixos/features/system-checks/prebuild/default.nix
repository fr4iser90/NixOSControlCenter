{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  checkScript = pkgs.writeScriptBin "check-and-build" ''
    #!${pkgs.bash}/bin/bash
    
    # Trap für CTRL+C
    trap '${ui.messages.error "Operation abgebrochen"}; exit 0' INT

    # Show usage if no arguments
    if [ $# -eq 0 ]; then
      ${ui.messages.info "Usage: check-and-build <command> [options]"}
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
  '';

in {
  imports = [
    ./checks/hardware/gpu.nix
    ./checks/hardware/cpu.nix
    ./checks/system/users.nix
  ];

  config = {
    # Command Center Registration
    features.command-center.commands.build = {
      name = "build";
      category = "system";
      description = "Build and activate NixOS configuration with safety checks";
      script = checkScript;
      arguments = [
        "switch"
        "boot"
        "test"
        "build"
        "--force"
      ];
      shortHelp = "build <command> [--force] - Build NixOS with safety checks";
      longHelp = ''
        Build and activate NixOS configuration with preflight safety checks

        Commands:
          switch    Build and activate configuration
          boot      Build boot configuration
          test      Test configuration
          build     Build only

        Options:
          --force   Skip safety checks
      '';
      interactive = true;
      dependencies = [ "system-checks" ];
    };

    environment.systemPackages = [ checkScript ];
  };
}