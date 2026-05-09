{ config, lib, pkgs, systemConfig, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry"; 
  hardwareConfigPath = "/etc/nixos/systemConfig/core/base/hardware/config.nix";

  prebuildScript = pkgs.writeScriptBin "prebuild-check-memory" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    ${ui.text.header "Memory Configuration Check"}
    
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    DETECTED_RAW_GB=$(( (TOTAL_MEM_KB + 524288) / 1048576 ))
    
    if [ $DETECTED_RAW_GB -ge 120 ]; then
      DETECTED_GB=128
    elif [ $DETECTED_RAW_GB -ge 60 ]; then
      DETECTED_GB=64
    elif [ $DETECTED_RAW_GB -ge 28 ]; then
      DETECTED_GB=32
    elif [ $DETECTED_RAW_GB -ge 14 ]; then
      DETECTED_GB=16
    elif [ $DETECTED_RAW_GB -ge 6 ]; then
      DETECTED_GB=8
    elif [ $DETECTED_RAW_GB -ge 3 ]; then
      DETECTED_GB=4
    else
      DETECTED_GB=$DETECTED_RAW_GB
    fi
    
    ${ui.messages.info "System Memory:"}
    ${ui.tables.keyValue "Total RAM" "$DETECTED_GB GB"}
    
    REAL_CONFIG_FILE=$(readlink -f "${hardwareConfigPath}" 2>/dev/null || echo "${hardwareConfigPath}")
    
    if [ ! -f "$REAL_CONFIG_FILE" ]; then
      ${ui.messages.info "hardware-config.nix not found, creating it..."}
      update-hardware-config "${hardwareConfigPath}" "memory" "$DETECTED_GB"
      ${ui.badges.success "hardware-config.nix created with detected memory."}
      exit 0
    fi
    
    if ! CONFIGURED_GB=$(grep -E 'sizeGB\s*=' "$REAL_CONFIG_FILE" 2>/dev/null | grep -oE '[0-9]+' | head -1); then
      ${ui.messages.warning "Memory size not configured in hardware-config.nix, setting detected value..."}
      update-hardware-config "${hardwareConfigPath}" "memory" "$DETECTED_GB"
      ${ui.badges.success "Memory size set to $DETECTED_GB GB."}
      exit 0
    fi
    
    ${ui.text.subHeader "Memory Configuration:"}
    ${ui.tables.keyValue "Detected" "$DETECTED_GB GB"}
    ${ui.tables.keyValue "Configured" "$CONFIGURED_GB GB"}
    
    if [ "$DETECTED_GB" != "$CONFIGURED_GB" ]; then
      ${ui.messages.warning "Memory configuration mismatch! Auto-updating..."}
      ${ui.messages.warning "System configured for $CONFIGURED_GB GB but detected $DETECTED_GB GB"}
      
      update-hardware-config "${hardwareConfigPath}" "memory" "$DETECTED_GB"
      ${ui.badges.success "Memory configuration updated to $DETECTED_GB GB."}
    else
      ${ui.badges.success "Memory configuration matches hardware."}
    fi
    
    exit 0
  '';

in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ prebuildScript ];
    }
    (cliRegistry.registerCommandsFor "system-checks-memory" [
      {
        name = "check-memory";
        domain = "system";
        category = "system-checks";
        internal = true;
        description = "Check memory configuration before system rebuild";
        script = "${prebuildScript}/bin/prebuild-check-memory";
        shortHelp = "check-memory - Verify RAM configuration";
        longHelp = ''
          Check system memory configuration before system rebuild
          
          Checks:
          - Detects installed RAM size
          - Compares with configured memory setting
          - Auto-updates hardware-config.nix if needed
        '';
        interactive = false;
        dependencies = [ "system-checks" ];
      }
      ])
  ];
}
