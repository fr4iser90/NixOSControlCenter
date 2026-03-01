{ config, lib, pkgs, ... }:

with lib;

let
  # Use hardcoded path for core module
  runtimeDiscovery = (import ../../lib/runtime_discovery.nix { inherit lib pkgs; }).runtimeDiscovery;

  # Get module-manager path (relative to this file: ui/tui/module-manager-tui.nix)
  # Go up to module-manager root
  moduleManagerPath = ../..;

  # Build module-specific binary with its own TUI files
  # Each module builds its own isolated binary
  bubbleTeaBinary = config.core.management.tui-engine.createTuiBinary {
    modulePath = moduleManagerPath;
    moduleName = "module-manager";
  };

  # Separate Runtime Discovery Script
  runtimeDiscoveryScript = pkgs.writeScript "runtime-discovery" ''
    #!${pkgs.bash}/bin/bash
    ${runtimeDiscovery}
  '';

  # Create action scripts
  actionScripts = {
  getModuleList = pkgs.writeScript "get-module-list" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
   # echo "DEBUG: Starting runtime discovery..." >&2
    ${runtimeDiscoveryScript}
  '';

    getFilterPanel = pkgs.writeScript "get-filter-panel" ''
      #!${pkgs.bash}/bin/bash
      echo "🔍 FILTERS:"
      echo "Status: All"
      echo "Category: All"
      echo "Search: Active"
    '';

    getDetailsPanel = pkgs.writeScript "get-details-panel" ''
      #!${pkgs.bash}/bin/bash
      echo "ℹ️ DETAILS:"
      echo "Select module to view details..."
    '';

    getActionsPanel = pkgs.writeScript "get-actions-panel" ''
      #!${pkgs.bash}/bin/bash
      echo "⚡ ACTIONS:"
      echo "[e] Enable  [d] Disable"
      echo "[r] Refresh  [q] Quit"
    '';
  };

  # Main TUI script
  moduleManagerTuiScript = pkgs.writeScriptBin "ncc-module-manager-tui" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    # echo "DEBUG: TUI script starting" >&2
    # echo "DEBUG: Checking if binary exists: ${bubbleTeaBinary}/bin/module-manager-tui" >&2
    # ls -la ${bubbleTeaBinary}/bin/ >&2 || # echo "DEBUG: Binary directory listing failed" >&2
    
    # Call the Go binary with the action script paths as arguments
    # echo "DEBUG: Executing Go binary..." >&2
    # Call the module-specific binary (module-manager-tui, not generic tui-engine)
    exec ${bubbleTeaBinary}/bin/module-manager-tui \
      "${actionScripts.getModuleList}" \
      "${actionScripts.getFilterPanel}" \
      "${actionScripts.getDetailsPanel}" \
      "${actionScripts.getActionsPanel}"
  '';

in {
  # Add the script to system packages like SSH manager
  environment.systemPackages = [ moduleManagerTuiScript ];

  # Store the script reference for core module
  core.management.tui-engine.moduleManagerTuiScript = moduleManagerTuiScript;
}
