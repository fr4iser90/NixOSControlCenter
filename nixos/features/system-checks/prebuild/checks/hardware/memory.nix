{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.features.terminal-ui.api;

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
    
    if [ ! -f /etc/nixos/system-config.nix ]; then
      ${ui.messages.error "system-config.nix not found"}
      exit 1
    fi
    
    # Check if memory section exists
    if ! grep -q 'memory = {' /etc/nixos/system-config.nix; then
      ${ui.messages.info "Memory configuration not found"}
      
      # Ask for confirmation before adding
      read -p "Add memory configuration to system-config.nix? [y/N] " response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        # Find hardware section and add memory configuration
        if ! grep -q 'hardware = {' /etc/nixos/system-config.nix; then
          ${ui.messages.error "Hardware section not found in system-config.nix"}
          exit 1
        fi
        
        # Use sudo to ensure we have permission
        sudo sed -i '/hardware = {/a\    memory = {\n      sizeGB = '"$DETECTED_GB"';\n    };' /etc/nixos/system-config.nix
        ${ui.badges.success "Memory configuration added."}
      else
        ${ui.badges.info "Configuration left unchanged."}
      fi
      exit 0
    fi
    
    # Get configured memory size
    if ! CONFIGURED_GB=$(grep -A2 'memory = {' /etc/nixos/system-config.nix | grep 'sizeGB' | grep -o '[0-9]\+'); then
      ${ui.messages.info "Memory size not configured"}
      
      # Ask for confirmation before adding
      read -p "Add memory size configuration? [y/N] " response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        # Use sudo to ensure we have permission
        sudo sed -i '/memory = {/a\      sizeGB = '"$DETECTED_GB"';' /etc/nixos/system-config.nix
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
        # Use sudo to ensure we have permission
        sudo sed -i "s/sizeGB = $CONFIGURED_GB/sizeGB = $DETECTED_GB/" /etc/nixos/system-config.nix
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
          - Can update system-config.nix if needed
          
          Interactive: Yes (for updating configuration)
        '';
        interactive = true;
        dependencies = [ "system-checks" ];
      }
    ];
  };
}