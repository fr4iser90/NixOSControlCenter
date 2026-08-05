{ config, lib, pkgs, systemConfig, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";
  hw = import ../../../../../lib/hardware-config-writer.nix { inherit pkgs lib systemConfig; };

  prebuildScript = pkgs.writeScriptBin "prebuild-check-cpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${hw.preamble}

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
      ${ui.messages.error "Could not detect CPU information"}
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
      ${ui.messages.info "hardware config missing cpu, creating..."}
      _update_cpu "$DETECTED"
      ${ui.badges.success "hardware config created with detected CPU."}
      exit 0
    fi

    CONFIGURED=$(echo "$CURRENT" | grep 'cpu =' | head -1 | cut -d'"' -f2 || echo "")
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
