{ config, lib, pkgs, systemConfig }:

let
  desktopConfigPath = "/etc/nixos/configs/desktop-config.nix";
in
pkgs.writeShellScriptBin "update-desktop-config" ''
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
''
