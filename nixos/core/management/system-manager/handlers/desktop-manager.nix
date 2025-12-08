{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.core.cli-formatter.api;
  commandCenter = config.core.command-center;
  hostname = systemConfig.hostName;
  desktopConfigPath = "/etc/nixos/configs/desktop-config.nix";

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

    # Apply the changes
    echo "Rebuilding system..."
    sudo nixos-rebuild switch --flake /etc/nixos#${hostname}

    echo "Desktop configuration updated successfully!"
  '';

in {
  config = {
    environment.systemPackages = [ enableDesktopScript updateDesktopConfig ];

    core.command-center.commands = [
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
