{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.features.terminal-ui.api;
  hardwareConfigPath = "/etc/nixos/configs/hardware-config.nix";

  # Helper function to update hardware-config.nix
  updateHardwareConfig = pkgs.writeShellScriptBin "update-hardware-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    local config_file="$1"
    local cpu_value="$2"
    
    # Create configs directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Read existing config if it exists
    local existing_gpu="none"
    local existing_memory=""
    
    if [ -f "$config_file" ]; then
      existing_gpu=$(grep -o 'gpu = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "none")
      existing_memory=$(grep -A2 'ram = {' "$config_file" 2>/dev/null || echo "")
    fi
    
    # Write complete hardware-config.nix
    if [ -n "$existing_memory" ]; then
      cat > "$config_file" <<EOF
{
  hardware = {
    cpu = "$cpu_value";
    gpu = "$existing_gpu";
$existing_memory
  };
}
EOF
    else
      cat > "$config_file" <<EOF
{
  hardware = {
    cpu = "$cpu_value";
    gpu = "$existing_gpu";
  };
}
EOF
    fi
  '';

  prebuildScript = pkgs.writeScriptBin "prebuild-check-cpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # CPU Detection using lscpu
    if ! CPU_INFO=$(${pkgs.util-linux}/bin/lscpu); then
      ${ui.messages.error "Could not detect CPU information"}
      exit 1
    fi
    
    # CPU Vendor Detection
    if echo "$CPU_INFO" | grep -qi "GenuineIntel"; then
      DETECTED="intel"
    elif echo "$CPU_INFO" | grep -qi "AuthenticAMD"; then
      DETECTED="amd" 
    else
      DETECTED="none"
    fi
    
    # Check if hardware-config.nix exists
    if [ ! -f "${hardwareConfigPath}" ]; then
      ${ui.messages.info "hardware-config.nix not found, creating it..."}
      ${updateHardwareConfig}/bin/update-hardware-config "${hardwareConfigPath}" "$DETECTED"
      ${ui.badges.success "hardware-config.nix created with detected CPU."}
      exit 0
    fi
    
    if ! CONFIGURED=$(grep 'cpu =' "${hardwareConfigPath}" | cut -d'"' -f2); then
      ${ui.messages.error "Could not find CPU configuration in hardware-config.nix"}
      exit 1
    fi
    
    # Immer Info anzeigen
    ${ui.messages.info "Detected CPU: $DETECTED"}
    ${ui.messages.info "Configured CPU: $CONFIGURED"}
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.messages.warning "CPU configuration mismatch!"}
      ${ui.messages.warning "System configured for $CONFIGURED but detected $DETECTED"}
      
      # Update CPU configuration
      ${updateHardwareConfig}/bin/update-hardware-config "${hardwareConfigPath}" "$DETECTED"
      ${ui.badges.success "Configuration updated."}
    else
      ${ui.badges.success "CPU configuration matches hardware."}
    fi
    
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ prebuildScript updateHardwareConfig ];
  };
}
