{ config, lib, pkgs, systemConfig, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  hw = import ../../../../../lib/hardware-config-writer.nix { inherit pkgs lib systemConfig; };

  prebuildScript = pkgs.writeScriptBin "prebuild-check-memory" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${hw.preamble}

    _update_memory() {
      local new_value="$1"
      local current existing_cpu existing_gpu
      current=$(ncc_read_module_config "core/base/hardware" 2>/dev/null || echo "{}")
      existing_cpu=$(echo "$current" | grep -o 'cpu = "[^"]*"' | head -1 | cut -d'"' -f2 || echo "none")
      existing_gpu=$(echo "$current" | grep -o 'gpu = "[^"]*"' | head -1 | cut -d'"' -f2 || echo "none")
      existing_cpu="''${existing_cpu:-none}"
      existing_gpu="''${existing_gpu:-none}"
      ncc_write_module_config "core/base/hardware" "{
  cpu = \"$existing_cpu\";
  gpu = \"$existing_gpu\";
  ram = {
    sizeGB = $new_value;
  };
}"
    }

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

    CURRENT=$(ncc_read_module_config "core/base/hardware" 2>/dev/null || echo "{}")
    if ! echo "$CURRENT" | grep -qE 'sizeGB\s*='; then
      ${ui.messages.info "hardware config missing memory, creating..."}
      _update_memory "$DETECTED_GB"
      ${ui.badges.success "hardware config created with detected memory."}
      exit 0
    fi

    CONFIGURED_GB=$(echo "$CURRENT" | grep -E 'sizeGB\s*=' | grep -oE '[0-9]+' | head -1 || echo "")
    ${ui.text.subHeader "Memory Configuration:"}
    ${ui.tables.keyValue "Detected" "$DETECTED_GB GB"}
    ${ui.tables.keyValue "Configured" "$CONFIGURED_GB GB"}

    if [ "$DETECTED_GB" != "$CONFIGURED_GB" ]; then
      ${ui.messages.warning "Memory configuration mismatch! Auto-updating..."}
      ${ui.messages.warning "System configured for $CONFIGURED_GB GB but detected $DETECTED_GB GB"}
      _update_memory "$DETECTED_GB"
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
          Check system memory configuration before system rebuild (layout-aware).
        '';
        interactive = false;
        dependencies = [ "system-checks" ];
      }
      ])
  ];
}
