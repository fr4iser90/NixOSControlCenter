{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";
  hw = import ../../../../../lib/hardware-config-writer.nix { inherit pkgs lib systemConfig getModuleConfig; };

  prebuildScript = pkgs.writeScriptBin "prebuild-check-cpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${hw.preamble}

    VERBOSE="''${NCC_PREFLIGHT_VERBOSE:-0}"

    _update_cpu() {
      local new_value="$1"
      local current existing_gpu existing_memory
      current=$(ncc_read_module_config "core/base/hardware" 2>/dev/null || echo "{}")
      existing_gpu=$(echo "$current" | grep -o 'gpu = "[^"]*"' | head -1 | cut -d'"' -f2 || echo "none")
      existing_gpu="''${existing_gpu:-none}"
      existing_memory=$(echo "$current" | grep -A3 'ram' || true)
      local content
      if echo "$existing_memory" | grep -q 'sizeGB'; then
        local size
        size=$(echo "$existing_memory" | grep -o 'sizeGB = [^;]*' | head -1 | sed 's/sizeGB = //;s/;//')
        content="{
  cpu = \"$new_value\";
  gpu = \"$existing_gpu\";
  ram = {
    sizeGB = $size;
  };
}"
      else
        content="{
  cpu = \"$new_value\";
  gpu = \"$existing_gpu\";
}"
      fi
      ncc_write_module_config "core/base/hardware" "$content"
    }

    if ! CPU_INFO=$(${pkgs.util-linux}/bin/lscpu); then
      ${ui.badges.error "CPU: could not detect"}
      exit 1
    fi

    if echo "$CPU_INFO" | grep -qi "GenuineIntel"; then
      DETECTED="intel"
    elif echo "$CPU_INFO" | grep -qi "AuthenticAMD"; then
      DETECTED="amd"
    else
      DETECTED="none"
    fi

    CURRENT=$(ncc_read_module_config "core/base/hardware" 2>/dev/null || echo "{}")
    if ! echo "$CURRENT" | grep -q 'cpu ='; then
      _update_cpu "$DETECTED"
      ${ui.badges.warning "CPU: was unset → set to $DETECTED"}
      ${ui.badges.success "CPU: $DETECTED"}
      exit 0
    fi

    CONFIGURED=$(echo "$CURRENT" | grep 'cpu =' | head -1 | cut -d'"' -f2 || echo "")

    if [ "$VERBOSE" = "1" ]; then
      echo "  detected:   $DETECTED"
      echo "  configured: $CONFIGURED"
    fi

    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.badges.warning "CPU: was $CONFIGURED → set to $DETECTED"}
      _update_cpu "$DETECTED"
      ${ui.badges.success "CPU: $DETECTED"}
    else
      ${ui.badges.success "CPU: $DETECTED"}
    fi

    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ prebuildScript ];
  };
}
