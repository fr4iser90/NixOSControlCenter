{ config, lib, pkgs, systemConfig, getModuleApi, ... }:

let
  # GENERISCH: CLI Formatter API über getModuleApi beziehen
  ui = getModuleApi "cli-formatter"; 

  hardwareConfigPath = "/etc/nixos/systemConfig/core/base/hardware/config.nix";
  
  prebuildScript = pkgs.writeScriptBin "prebuild-check-cpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    _update_cpu() {
      local new_value="$1"
      local config_file="${hardwareConfigPath}"
      mkdir -p "$(dirname "$config_file")"
      local existing_gpu=$(grep -o 'gpu = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "none")
      local existing_memory=$(grep -A2 'ram = {' "$config_file" 2>/dev/null || echo "")
      if [ -n "$existing_memory" ]; then
        cat > "$config_file" <<EOF
{
  cpu = "$new_value";
  gpu = "$existing_gpu";
$existing_memory
}
EOF
      else
        cat > "$config_file" <<EOF
{
  cpu = "$new_value";
  gpu = "$existing_gpu";
}
EOF
      fi
    }

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
    
    # Check if core/base/hardware/config.nix exists
    if [ ! -f "${hardwareConfigPath}" ]; then
      ${ui.messages.info "core/base/hardware/config.nix not found, creating it..."}
      _update_cpu "$DETECTED"
      ${ui.badges.success "core/base/hardware/config.nix created with detected CPU."}
      exit 0
    fi
    
    if ! CONFIGURED=$(grep 'cpu =' "${hardwareConfigPath}" | cut -d'"' -f2); then
      ${ui.messages.error "Could not find CPU configuration in core/base/hardware/config.nix"}
      exit 1
    fi
    
    ${ui.messages.info "Detected CPU: $DETECTED"}
    ${ui.messages.info "Configured CPU: $CONFIGURED"}
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.messages.warning "CPU configuration mismatch!"}
      ${ui.messages.warning "System configured for $CONFIGURED but detected $DETECTED"}
      
      _update_cpu "$DETECTED"
      ${ui.badges.success "Configuration updated."}
    else
      ${ui.badges.success "CPU configuration matches hardware."}
    fi
    
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ prebuildScript ];
  };
}
