{ config, pkgs, ... }:

let
  desktopConfigPath = "/etc/nixos/configs/desktop-config.nix";
  featuresConfigPath = "/etc/nixos/configs/features-config.nix";
  
  buildSwitch = ''
    echo "Applying configuration changes..."
    sudo ncc build switch
  '';

  # Helper to update desktop-config.nix
  updateDesktopConfig = pkgs.writeShellScriptBin "update-desktop-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    local config_file="${desktopConfigPath}"
    local key="$1"
    local value="$2"
    
    # Create configs directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Read existing desktop config if it exists
    local existing_enable="true"
    local existing_env="plasma"
    local existing_display_mgr="sddm"
    local existing_display_server="wayland"
    local existing_session="plasma"
    local existing_dark="true"
    local existing_audio="pipewire"
    
    if [ -f "$config_file" ]; then
      existing_enable=$(grep -o 'enable = [^;]*' "$config_file" 2>/dev/null | grep -o '[^=]*$' | tr -d ' ' || echo "true")
      existing_env=$(grep -o 'environment = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
      existing_display_mgr=$(grep -o 'manager = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "sddm")
      existing_display_server=$(grep -o 'server = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "wayland")
      existing_session=$(grep -o 'session = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
      existing_dark=$(grep -o 'dark = [^;]*' "$config_file" 2>/dev/null | grep -o '[^=]*$' | tr -d ' ' || echo "true")
      existing_audio=$(grep -o 'audio = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "pipewire")
    fi
    
    # Update the specific key
    case "$key" in
      "environment") existing_env="$value" ;;
      "manager") existing_display_mgr="$value" ;;
      "server") existing_display_server="$value" ;;
      "session") existing_session="$value" ;;
      "dark") existing_dark="$value" ;;
      "audio") existing_audio="$value" ;;
      "enable") existing_enable="$value" ;;
    esac
    
    # Write complete desktop-config.nix
    cat > "$config_file" <<EOF
{
  # Desktop-Environment
  desktop = {
    enable = $existing_enable;
    environment = "$existing_env";
    display = {
      manager = "$existing_display_mgr";
      server = "$existing_display_server";
      session = "$existing_session";
    };
    theme = {
      dark = $existing_dark;
    };
    audio = "$existing_audio";
  };
}
EOF
  '';

  # Helper to update features-config.nix
  updateFeaturesConfig = pkgs.writeShellScriptBin "update-features-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    local config_file="${featuresConfigPath}"
    local feature="$1"
    local value="$2"
    
    # Create configs directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Read existing feature states
    declare -A features
    feature_list="system-logger system-checks system-updater system-config-manager ssh-client-manager ssh-server-manager bootentry-manager homelab-manager vm-manager ai-workspace"
    for f in $feature_list; do
      if [ -f "$config_file" ]; then
        status=$(${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
          "(import $config_file).features.$f or false" 2>/dev/null || echo "false")
        features["$f"]="$status"
      else
        features["$f"]="false"
      fi
    done
    
    # Update the specific feature
    features["$feature"]="$value"
    
    # Write complete features-config.nix
    cat > "$config_file" <<EOF
{
  features = {
    system-logger = ''${features["system-logger"]};
    system-checks = ''${features["system-checks"]};
    system-updater = ''${features["system-updater"]};
    system-config-manager = ''${features["system-config-manager"]};
    ssh-client-manager = ''${features["ssh-client-manager"]};
    ssh-server-manager = ''${features["ssh-server-manager"]};
    bootentry-manager = ''${features["bootentry-manager"]};
    homelab-manager = ''${features["homelab-manager"]};
    vm-manager = ''${features["vm-manager"]};
    ai-workspace = ''${features["ai-workspace"]};
  };
}
EOF
  '';

in {
  environment.systemPackages = [
    updateDesktopConfig
    updateFeaturesConfig
    (pkgs.writeShellScriptBin "ncc-config" ''
      case "$1" in
        set)
          case "$2" in
            feature)
              ${updateFeaturesConfig}/bin/update-features-config "$3" "$4"
              ${buildSwitch}
              ;;
            desktop)
              case "$3" in
                enable|disable)
                  ${updateDesktopConfig}/bin/update-desktop-config "enable" "$3"
                  ${buildSwitch}
                  ;;
                environment|manager|server|session|dark|audio)
                  ${updateDesktopConfig}/bin/update-desktop-config "$3" "$4"
                  ${buildSwitch}
                  ;;
                *)
                  echo "Invalid desktop option: $3"
                  echo "Valid options: enable, disable, environment, manager, server, session, dark, audio"
                  exit 1
                  ;;
              esac
              ;;
            *)
              echo "Invalid option: $2"
              echo "Valid options: feature, desktop"
              exit 1
              ;;
          esac
          ;;
        *)
          echo "Usage: ncc-config set feature|desktop <option> <value>"
          exit 1
          ;;
      esac
    '')
  ];
}
