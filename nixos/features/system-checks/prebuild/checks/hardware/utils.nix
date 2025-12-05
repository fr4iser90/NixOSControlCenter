{ config, lib, pkgs, ... }:

{
  # Shared helper script for hardware config updates
  # Each script (CPU, GPU, Memory) can use this
  # It only changes the specific value and keeps all others unchanged
  
  config = {
    # Shared update-hardware-config script
    # Usage: update-hardware-config <config_file> <type> <value>
    # type: "cpu" | "gpu" | "memory"
    # value: the new value (e.g. "amd", "nvidia", "32")
    environment.systemPackages = [
    (pkgs.writeShellScriptBin "update-hardware-config" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      
      config_file="$1"
      update_type="$2"  # "cpu", "gpu", or "memory"
      new_value="$3"
      
      # Create configs directory if it doesn't exist
      mkdir -p "$(dirname "$config_file")"
      
      # Read existing values from config file
      existing_cpu="none"
      existing_gpu="none"
      existing_memory=""
      
      if [ -f "$config_file" ]; then
        existing_cpu=$(grep -o 'cpu = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "none")
        existing_gpu=$(grep -o 'gpu = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "none")
        existing_memory=$(grep -A2 'ram = {' "$config_file" 2>/dev/null || echo "")
      fi
      
      # Update only the specified value
      case "$update_type" in
        "cpu")
          cpu_value="$new_value"
          gpu_value="$existing_gpu"
          memory_block="$existing_memory"
          ;;
        "gpu")
          cpu_value="$existing_cpu"
          gpu_value="$new_value"
          memory_block="$existing_memory"
          ;;
        "memory")
          cpu_value="$existing_cpu"
          gpu_value="$existing_gpu"
          memory_block="    ram = {
      sizeGB = $new_value;
    };"
          ;;
        *)
          echo "Error: Unknown update type: $update_type" >&2
          echo "Usage: update-hardware-config <file> <cpu|gpu|memory> <value>" >&2
          exit 1
          ;;
      esac
      
      # Write complete hardware-config.nix with updated value
      if [ -n "$memory_block" ] && [ "$update_type" != "memory" ]; then
        # Memory block exists and we're not updating memory
        cat > "$config_file" <<EOF
{
  hardware = {
    cpu = "$cpu_value";
    gpu = "$gpu_value";
$memory_block
  };
}
EOF
      elif [ "$update_type" = "memory" ] || [ -n "$memory_block" ]; then
        # We're updating memory or memory block exists
        cat > "$config_file" <<EOF
{
  hardware = {
    cpu = "$cpu_value";
    gpu = "$gpu_value";
$memory_block
  };
}
EOF
      else
        # No memory block
        cat > "$config_file" <<EOF
{
  hardware = {
    cpu = "$cpu_value";
    gpu = "$gpu_value";
  };
}
EOF
      fi
    '')
    ];
  };
}

