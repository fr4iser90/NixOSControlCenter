# Module Manager TUI Actions API
# Provides actions for the Gum-based TUI

{ config, lib, pkgs, getModuleApi, ... }:

let
  # Get APIs
  ui = getModuleApi "cli-formatter";
  runtimeDiscovery = (import ../lib/runtime_discovery.nix { inherit lib pkgs; }).runtimeDiscovery;

  # Create toggle module script
  toggleModuleScript = pkgs.writeScriptBin "toggle-module" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    local module_name="$1"
    local action="$2"
    local config_file="/etc/nixos/configs/$module_name/config.nix"

    echo "Setting $module_name to $action..."

    # Create config directory if needed
    mkdir -p "$(dirname "$config_file")"

    # Create or update config
    cat > "$config_file" << EOF
{ config, lib, ... }:
{
  $module_name.enable = $action;
}
EOF

    echo "$module_name $action"
  '';

in {
  # Get module list for display
  getModuleList = ''
    echo "DEBUG: Starting runtime discovery..." >&2
    ${runtimeDiscovery}
    echo "DEBUG: Runtime discovery finished, calling main..." >&2
    main 2>&1 | head -10 >&2
    main | jq -r '.[] | "\(.id)|\(.name)|\(.description)|\(.category)|\(.status)|\(.version)|\(.path)"' 2>&1 || echo "ERROR: jq failed" >&2
  '';

  # Get filter panel content
  getFilterPanel = ''
    echo "🔍 FILTERS:"
    echo "Status: All"
    echo "Category: All"
    echo "Search: Active"
  '';

  # Get details panel content
  getDetailsPanel = ''
    echo "ℹ️ DETAILS:"
    echo "Select module to view details..."
  '';

  # Get actions panel content
  getActionsPanel = ''
    echo "⚡ ACTIONS:"
    echo "[e] Enable  [d] Disable"
    echo "[r] Refresh  [q] Quit"
  '';

  # Reference to toggle script
  toggle_module_script = toggleModuleScript;
}
