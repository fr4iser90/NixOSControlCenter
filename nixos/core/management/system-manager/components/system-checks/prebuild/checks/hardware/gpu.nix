{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cliRegistry = getModuleApi "cli-registry";
  ui = getModuleApi "cli-formatter";
  hw = import ../../../../../lib/hardware-config-writer.nix { inherit pkgs lib systemConfig getModuleConfig; };

  prebuildScript = pkgs.writeScriptBin "prebuild-check-gpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${hw.preamble}

    VERBOSE="''${NCC_PREFLIGHT_VERBOSE:-0}"

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

    DETECTED="none"
    declare -A gpu_types
    amd_count=0
    DEVICE_SUMMARY=""

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
                DEVICE_SUMMARY="''${DEVICE_SUMMARY}''${DEVICE_SUMMARY:+; }$device"
                if [ "$VERBOSE" = "1" ]; then
                  echo "  device: $device"
                  echo "  bus:    $bus_id  vendor: $vendor_id  class: $class_code"
                fi
                ;;
        esac
    done < <(${pkgs.pciutils}/bin/lspci -nn | grep -E "\[0300\]|\[0302\]|\[0380\]" || true)

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
                if [ "$VERBOSE" = "1" ]; then
                  echo "  virt: $virt_type"
                fi
            fi
        fi
    fi

    CURRENT=$(ncc_read_module_config "core/base/hardware" 2>/dev/null || echo "{}")
    if ! echo "$CURRENT" | grep -q 'gpu ='; then
      _update_gpu "$DETECTED"
      ${ui.badges.warning "GPU: was unset → set to $DETECTED"}
      ${ui.badges.success "GPU: $DETECTED"}
      exit 0
    fi

    CONFIGURED=$(echo "$CURRENT" | grep 'gpu =' | head -1 | cut -d'"' -f2 || echo "")

    if [ "$VERBOSE" = "1" ]; then
      echo "  detected:   $DETECTED"
      echo "  configured: $CONFIGURED"
    fi

    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.badges.warning "GPU: was $CONFIGURED → set to $DETECTED"}
      _update_gpu "$DETECTED"
      ${ui.badges.success "GPU: $DETECTED"}
    else
      ${ui.badges.success "GPU: $DETECTED"}
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
          Check GPU configuration before system rebuild.
          Quiet by default; details with NCC_PREFLIGHT_VERBOSE=1.
        '';
        interactive = false;
        dependencies = [ "system-checks" ];
      }
    ])
  ];
}
