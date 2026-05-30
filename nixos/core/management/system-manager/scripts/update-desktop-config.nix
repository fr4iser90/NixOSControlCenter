{ config, lib, pkgs, systemConfig }:

let
  configPaths = import ../lib/config-paths.nix;
  desktopConfigPath = configPaths.core.base.desktop;
in
pkgs.writeShellScriptBin "update-desktop-config" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  config_file="${desktopConfigPath}"
  enable_value="$1"

  mkdir -p "$(dirname "$config_file")"

  existing_env="plasma"
  existing_display_mgr="sddm"
  existing_display_server="wayland"
  existing_session="plasma"
  existing_dark="true"
  existing_audio="pipewire"

  if [ -f "$config_file" ]; then
    existing_env=$(grep -o 'environment = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
    existing_display_mgr=$(grep -o 'manager = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "sddm")
    existing_display_server=$(grep -o 'server = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "wayland")
    existing_session=$(grep -o 'session = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
    existing_dark=$(grep -o 'dark = [^;]*' "$config_file" 2>/dev/null | grep -o '[^=]*$' | tr -d ' ' || echo "true")
    existing_audio=$(grep -o 'audio = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "pipewire")
  elif [ -f "/etc/nixos/systemConfig/desktop-config.nix" ]; then
    legacy_file="/etc/nixos/systemConfig/desktop-config.nix"
    existing_env=$(grep -o 'environment = "[^"]*"' "$legacy_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
    existing_display_mgr=$(grep -o 'manager = "[^"]*"' "$legacy_file" 2>/dev/null | cut -d'"' -f2 || echo "sddm")
    existing_display_server=$(grep -o 'server = "[^"]*"' "$legacy_file" 2>/dev/null | cut -d'"' -f2 || echo "wayland")
    existing_session=$(grep -o 'session = "[^"]*"' "$legacy_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
    existing_dark=$(grep -o 'dark = [^;]*' "$legacy_file" 2>/dev/null | grep -o '[^=]*$' | tr -d ' ' || echo "true")
    existing_audio=$(grep -o 'audio = "[^"]*"' "$legacy_file" 2>/dev/null | cut -d'"' -f2 || echo "pipewire")
  fi

  cat > "$config_file" <<EOF
{
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
}
EOF

  # Remove legacy flat config if present
  if [ -f "/etc/nixos/systemConfig/desktop-config.nix" ]; then
    rm -f "/etc/nixos/systemConfig/desktop-config.nix"
  fi
''
