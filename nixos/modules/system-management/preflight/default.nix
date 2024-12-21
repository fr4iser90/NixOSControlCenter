{ config, lib, pkgs, systemConfig, reportingConfig, ... }:

with lib;

let
  checkAndBuild = pkgs.writeShellScriptBin "check-and-build" ''
    #!${pkgs.bash}/bin/bash
    
    # Show usage if no arguments
    if [ $# -eq 0 ]; then
      ${reportingConfig.formatting.section "Usage"}
      ${reportingConfig.formatting.keyValue "Command" "check-and-build <command> [options]"}
      
      ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
        echo -e "\nCommands:"
        echo "  switch    - Build and activate configuration"
        echo "  boot      - Build configuration and make it the boot default"
        echo "  test      - Build and activate, but don't add to boot menu"
        echo "  build     - Build configuration only"
        
        echo -e "\nOptions:"
        echo "  --force   - Skip all preflight checks"
        
        echo -e "\nExample:"
        echo "  check-and-build switch --flake /etc/nixos#Gaming"
        echo "  check-and-build switch --force"
      '' else ""}
      exit 1
    fi

    # Save current configuration state
    save_config() {
      ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then 
        reportingConfig.formatting.info "Saving current configuration state..." 
      else ""}
      echo '${builtins.toJSON {
        systemType = systemConfig.systemType or null;
        gpu = systemConfig.gpu or null;
        cpu = systemConfig.cpu or null;
        users = systemConfig.users or {};
      }}' > /etc/nixos/.system-config.previous.json
    }

    # Check for --force flag
    if [[ " $* " =~ " --force " ]]; then
      ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.minimal then 
        reportingConfig.formatting.warning "Bypassing preflight checks!"
      else ""}
      ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then 
        reportingConfig.formatting.info "Running nixos-rebuild..." 
      else ""}
      args=$(echo "$@" | sed 's/--force//')
      exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild $args
    fi

    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then 
      reportingConfig.formatting.section "Preflight Checks"
    else ""}
    
    # Run checks
    if ! preflight-check-users; then
      ${reportingConfig.formatting.error "User checks failed!"}
      ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then 
        reportingConfig.formatting.info "Use --force to bypass checks"
      else ""}
      exit 1
    fi

    if ! run-system.preflight.checks; then
      ${reportingConfig.formatting.error "System checks failed!"}
      ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then 
        reportingConfig.formatting.info "To bypass checks, use: check-and-build <command> --force"
      else ""}
      exit 1
    fi

    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.minimal then 
      reportingConfig.formatting.success "All checks passed!"
    else ""}
    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then 
      reportingConfig.formatting.info "Running nixos-rebuild..."
    else ""}

    # Save config and build
    save_config

    if ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"; then
      ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.minimal then 
        reportingConfig.formatting.success "Build successful!"
      else ""}
      exit 0
    else
      ${reportingConfig.formatting.error "Build failed!"}
      exit 1
    fi
  '';

in {
  imports = [
    ./checks/hardware/gpu.nix
    ./checks/hardware/cpu.nix
    ./checks/system/users.nix
    ./runners/cli.nix
  ];

  config = {
    environment.systemPackages = [ checkAndBuild ];
  };
}