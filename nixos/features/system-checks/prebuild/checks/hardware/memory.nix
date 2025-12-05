{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.features.terminal-ui.api;
  hardwareConfigPath = "/etc/nixos/configs/hardware-config.nix";
  
  # Use the shared update-hardware-config script from utils.nix
  # It will be automatically available via systemPackages

  prebuildScript = pkgs.writeScriptBin "prebuild-check-memory" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    ${ui.text.header "Memory Configuration Check"}
    
    # Get total memory in GB (rounded)
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    DETECTED_GB=$(( (TOTAL_MEM_KB + 524288) / 1048576 ))  # Round up to nearest GB
    
    # Show detected memory
    ${ui.messages.info "System Memory:"}
    ${ui.tables.keyValue "Total RAM" "$DETECTED_GB GB"}
    
    # Check if hardware-config.nix exists
    if [ ! -f "${hardwareConfigPath}" ]; then
      ${ui.messages.info "hardware-config.nix not found, creating it..."}
      
      # Ask for confirmation before creating
      read -p "Create hardware-config.nix with detected memory? [y/N] " response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        update-hardware-config "${hardwareConfigPath}" "memory" "$DETECTED_GB"
        ${ui.badges.success "hardware-config.nix created."}
      else
        ${ui.badges.info "Configuration left unchanged."}
      fi
      exit 0
    fi
    
    # Get configured memory size
    if ! CONFIGURED_GB=$(grep -A2 'ram = {' "${hardwareConfigPath}" | grep 'sizeGB' | grep -o '[0-9]\+' | head -1); then
      ${ui.messages.info "Memory size not configured in hardware-config.nix"}
      
      # Ask for confirmation before adding
      read -p "Add memory size configuration? [y/N] " response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        update-hardware-config "${hardwareConfigPath}" "memory" "$DETECTED_GB"
        ${ui.badges.success "Memory size configuration added."}
      else
        ${ui.badges.info "Configuration left unchanged."}
      fi
      exit 0
    fi
    
    # Show configuration
    ${ui.text.subHeader "Memory Configuration:"}
    ${ui.tables.keyValue "Detected" "$DETECTED_GB GB"}
    ${ui.tables.keyValue "Configured" "$CONFIGURED_GB GB"}
    
    # Compare and update if needed
    if [ "$DETECTED_GB" != "$CONFIGURED_GB" ]; then
      ${ui.messages.warning "Memory configuration mismatch!"}
      ${ui.messages.warning "System configured for $CONFIGURED_GB GB but detected $DETECTED_GB GB"}
      
      # Ask for confirmation
      read -p "Update memory configuration to $DETECTED_GB GB? [y/N] " response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        update-hardware-config "${hardwareConfigPath}" "memory" "$DETECTED_GB"
        ${ui.badges.success "Configuration updated."}
      else
        ${ui.badges.info "Configuration left unchanged."}
      fi
    else
      ${ui.badges.success "Memory configuration matches hardware."}
    fi
    
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ prebuildScript ];
    features.command-center.commands = [
      {
        name = "check-memory";
        category = "system-checks";
        description = "Check memory configuration before system rebuild";
        script = "${prebuildScript}/bin/prebuild-check-memory";
        shortHelp = "check-memory - Verify RAM configuration";
        longHelp = ''
          Check system memory configuration before system rebuild
          
          Checks:
          - Detects installed RAM size
          - Compares with configured memory setting
          - Can update hardware-config.nix if needed
          
          Interactive: Yes (for updating configuration)
        '';
        interactive = true;
        dependencies = [ "system-checks" ];
      }
    ];
  };
}
