{ config, lib, pkgs, systemConfig, getModuleApi, ... }:

let
  cliRegistry = getModuleApi "cli-registry";
  ui = getModuleApi "cli-formatter";
  hw = import ../../../../../lib/hardware-config-writer.nix { inherit pkgs lib systemConfig; };

  prebuildScript = pkgs.writeScriptBin "prebuild-check-gpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${hw.preamble}

    _update_gpu() {
      local new_value="$1"
      local current existing_cpu existing_memory size
      current=$(ncc_read_module_config "core/base/hardware" 2>/dev/null || echo "{}")
      existing_cpu=$(echo "$current" | grep -o 'cpu = "[^"]*"' | head -1 | cut -d'"' -f2 || echo "none")
      existing_cpu="''${existing_cpu:-none}"
      existing_memory=$(echo "$current" | grep -A3 'ram' || true)
      local content
      if echo "$existing_memory" | grep -q 'sizeGB'; then
        size=$(echo "$existing_memory" | grep -o 'sizeGB = [^;]*' | head -1 | sed 's/sizeGB = //;s/;//')
        content="{
  cpu = \"$existing_cpu\";
  gpu = \"$new_value\";
  ram = {
    sizeGB = $size;
  };
}"
      else
        content="{
  cpu = \"$existing_cpu\";
  gpu = \"$new_value\";
}"
      fi
      ncc_write_module_config "core/base/hardware" "$content"
    }

    ${ui.text.header "GPU Configuration Check"}

    DETECTED="none"

    declare -A gpu_types
    amd_count=0

    while IFS= read -r line; do
        bus_id=$(echo "$line" | cut -d' ' -f1)
        class_code=$(${pkgs.pciutils}/bin/lspci -n -s "$bus_id" | awk '{print $2}' | cut -d':' -f1)
        vendor_id=$(${pkgs.pciutils}/bin/lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f1)
        device=$(echo "$line" | sed 's/.*: //')

        case "$class_code" in
            "0300"|"0302"|"0380")
                case "$vendor_id" in
                    "10de") gpu_types["nvidia"]=1 ;;
                    "1002")
                        gpu_types["amd"]=1
                        amd_count=$((amd_count + 1))
                        ;;
                    "8086") gpu_types["intel"]=1 ;;
                esac

                ${ui.messages.info "Found GPU:"}
                ${ui.tables.keyValue "Device" "$device"}
                ${ui.tables.keyValue "Bus ID" "$bus_id"}
                ${ui.tables.keyValue "Vendor ID" "$vendor_id"}
                ${ui.tables.keyValue "Class Code" "$class_code"}
                ;;
        esac
    done < <(${pkgs.pciutils}/bin/lspci -nn | grep -E "\[0300\]|\[0302\]|\[0380\]")

    if [ "$amd_count" -gt 0 ]; then
      echo "AMD GPU count: $amd_count"
    fi

    if [[ ''${gpu_types["nvidia"]-0} -eq 1 && ''${gpu_types["intel"]-0} -eq 1 ]]; then
        DETECTED="nvidia-intel"
    elif [[ ''${gpu_types["amd"]-0} -eq 1 && ''${gpu_types["intel"]-0} -eq 1 ]]; then
        DETECTED="amd-intel"
    elif [[ $amd_count -eq 2 ]]; then
        DETECTED="amd-amd"
    elif [[ ''${gpu_types["nvidia"]-0} -eq 1 ]]; then
        DETECTED="nvidia"
    elif [[ ''${gpu_types["amd"]-0} -eq 1 ]]; then
        DETECTED="amd"
    elif [[ ''${gpu_types["intel"]-0} -eq 1 ]]; then
        DETECTED="intel"
    fi

    if [ "$DETECTED" = "none" ]; then
        if command -v ${pkgs.systemd}/bin/systemd-detect-virt &> /dev/null; then
            virt_type=$(${pkgs.systemd}/bin/systemd-detect-virt || echo "none")

            if [ "$virt_type" != "none" ]; then
                DETECTED="vm-gpu"
                ${ui.messages.info "Virtual Machine: $virt_type"}
                ${ui.messages.info "Virtual Display: $DETECTED"}
            fi
        fi
    fi

    CURRENT=$(ncc_read_module_config "core/base/hardware" 2>/dev/null || echo "{}")
    if ! echo "$CURRENT" | grep -q 'gpu ='; then
      ${ui.messages.info "hardware config missing gpu, creating..."}
      _update_gpu "$DETECTED"
      ${ui.badges.success "hardware config created with detected GPU."}
      exit 0
    fi

    CONFIGURED=$(echo "$CURRENT" | grep 'gpu =' | head -1 | cut -d'"' -f2 || echo "")
    ${ui.text.subHeader "GPU Configuration:"}
    ${ui.tables.keyValue "Detected" "$DETECTED"}
    ${ui.tables.keyValue "Configured" "$CONFIGURED"}

    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.messages.warning "GPU configuration mismatch! Auto-updating..."}
      ${ui.messages.warning "System configured for $CONFIGURED but detected $DETECTED"}
      _update_gpu "$DETECTED"
      ${ui.badges.success "GPU configuration updated to $DETECTED."}
    else
      ${ui.badges.success "GPU configuration matches hardware."}
    fi

    exit 0
  '';

in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ prebuildScript ];
    }
    (cliRegistry.registerCommandsFor "system-checks-gpu" [
      {
        name = "check-gpu";
        domain = "system";
        category = "system-checks";
        internal = true;
        description = "Check GPU configuration before system rebuild";
        script = "${prebuildScript}/bin/prebuild-check-gpu";
        shortHelp = "check-gpu - Verify GPU configuration";
        longHelp = ''
          Check GPU configuration before system rebuild

          Layout-aware: updates monolith (systemConfig.nix) or split leaf.
        '';
        interactive = false;
        dependencies = [ "system-checks" ];
      }
      ])
  ];
}
