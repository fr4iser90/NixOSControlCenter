{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.features.terminal-ui.api;
  commandCenter = config.features.command-center;
  hostname = systemConfig.hostName;
  desktopConfigPath = "/etc/nixos/configs/desktop-config.nix";
  featuresConfigPath = "/etc/nixos/configs/features-config.nix";

  # Helper to update desktop-config.nix
  updateDesktopConfig = pkgs.writeShellScriptBin "update-desktop-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    local config_file="${desktopConfigPath}"
    local enable_value="$1"
    
    # Create configs directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Read existing desktop config if it exists
    local existing_env="plasma"
    local existing_display_mgr="sddm"
    local existing_display_server="wayland"
    local existing_session="plasma"
    local existing_dark="true"
    local existing_audio="pipewire"
    
    if [ -f "$config_file" ]; then
      existing_env=$(grep -o 'environment = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
      existing_display_mgr=$(grep -o 'manager = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "sddm")
      existing_display_server=$(grep -o 'server = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "wayland")
      existing_session=$(grep -o 'session = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
      existing_dark=$(grep -o 'dark = [^;]*' "$config_file" 2>/dev/null | grep -o '[^=]*$' | tr -d ' ' || echo "true")
      existing_audio=$(grep -o 'audio = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "pipewire")
    fi
    
    # Write complete desktop-config.nix
    cat > "$config_file" <<EOF
{
  # Desktop-Environment
  desktop = {
    enable = $enable_value;
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
    system-logger = ${features["system-logger"]};
    system-checks = ${features["system-checks"]};
    system-updater = ${features["system-updater"]};
    system-config-manager = ${features["system-config-manager"]};
    ssh-client-manager = ${features["ssh-client-manager"]};
    ssh-server-manager = ${features["ssh-server-manager"]};
    bootentry-manager = ${features["bootentry-manager"]};
    homelab-manager = ${features["homelab-manager"]};
    vm-manager = ${features["vm-manager"]};
    ai-workspace = ${features["ai-workspace"]};
  };
}
EOF
  '';

  # Minimizing Homelab
  minimizeScript = pkgs.writeScriptBin "ncc-homelab-minimize" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    # Sudo check
    if [ "$EUID" -ne 0 ]; then
      echo "Error: This script must be run as root (use sudo)"
      exit 1
    fi

    echo "Disabling desktop..."
    ${updateDesktopConfig}/bin/update-desktop-config "false"

    echo "Enabling SSH Client & Server Manager..."
    ${updateFeaturesConfig}/bin/update-features-config "ssh-client-manager" "true"
    ${updateFeaturesConfig}/bin/update-features-config "ssh-server-manager" "true"

    echo "Applying changes with nixos-rebuild..."
    if sudo nixos-rebuild switch --flake /etc/nixos#${hostname}; then
      echo "System successfully minimized!"
    else
      echo "Rebuild failed! Check logs for details."
      exit 1
    fi
  '';

  # Enable or Disable Desktop
  enableDesktopScript = pkgs.writeScriptBin "enable-desktop" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Sudo check
    if [ "$EUID" -ne 0 ]; then
      echo "This script must be run as root (use sudo)"
      exit 1
    fi

    # Enable or disable desktop
    if [ "$1" == "disable" ]; then
      echo "Disabling desktop..."
      ${updateDesktopConfig}/bin/update-desktop-config "false"
    elif [ "$1" == "enable" ]; then
      echo "Enabling desktop..."
      ${updateDesktopConfig}/bin/update-desktop-config "true"
    else
      echo "Invalid option. Use 'enable' or 'disable'."
      exit 1
    fi

    echo "Applying changes with nixos-rebuild..."
    if sudo nixos-rebuild switch --flake /etc/nixos#${hostname}; then
      echo "Desktop configuration updated successfully!"
    else
      echo "Rebuild failed! Check logs for details."
      exit 1
    fi
  '';

in {
  config = {
    environment.systemPackages = [
      minimizeScript
      enableDesktopScript
      updateDesktopConfig
      updateFeaturesConfig
    ];

    features.command-center.commands = [
      {
        name = "homelab-minimize";
        description = "Minimize system configuration for homelab use";
        category = "system";
        script = "${minimizeScript}/bin/ncc-homelab-minimize";
        arguments = [];
        dependencies = [ "nix" ];
        shortHelp = "homelab-minimize - Disable desktop and enable SSH";
        longHelp = ''
          Minimizes system configuration by:
          - Disabling desktop environment
          - Enabling SSH client and server managers
          Requires sudo privileges and triggers system rebuild.
        '';
      }
      {
        name = "desktop-manager";
        description = "Enable or disable desktop environment";
        category = "system";
        script = "${enableDesktopScript}/bin/enable-desktop";
        arguments = [ "enable|disable" ];
        dependencies = [ "nix" ];
        shortHelp = "Enable or disable the desktop environment";
        longHelp = ''
          Allows enabling or disabling the desktop environment:
          - "enable" to activate the desktop
          - "disable" to deactivate the desktop
          Requires sudo privileges and triggers system rebuild.
        '';
      }
    ];
  };
}
