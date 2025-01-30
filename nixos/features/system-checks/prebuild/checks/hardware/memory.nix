{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;

  prebuildScript = pkgs.writeScriptBin "prebuild-check-memory" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
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
      ${ui.messages.info "Memory configuration not found, adding it..."}
      # Find hardware section and add memory configuration
      sed -i '/hardware = {/a\    memory = {\n      sizeGB = '"$DETECTED_GB"';\n    };' /etc/nixos/system-config.nix
      ${ui.badges.success "Memory configuration added."}
      exit 0
    fi
    
    # Get configured memory size
    if ! CONFIGURED_GB=$(grep -A2 'memory = {' /etc/nixos/system-config.nix | grep 'sizeGB' | grep -o '[0-9]\+'); then
      # If sizeGB is not found but memory section exists, add it
      sed -i '/memory = {/a\      sizeGB = '"$DETECTED_GB"';' /etc/nixos/system-config.nix
      ${ui.badges.success "Memory size configuration added."}
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
      
      # Update configuration
      sed -i "s/sizeGB = $CONFIGURED_GB/sizeGB = $DETECTED_GB/" /etc/nixos/system-config.nix
      ${ui.badges.success "Configuration updated."}
    else
      ${ui.badges.success "Memory configuration matches hardware."}
    fi
    
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ prebuildScript ];
  };
}