{ config, lib, pkgs, ... }:

with lib;

let
  # Use hardcoded path for core module
  runtimeDiscovery = (import ../../module-manager/lib/runtime_discovery.nix { inherit lib pkgs; }).runtimeDiscovery;

  # Build the Go binary using the same logic as package.nix
  # Use tuiEngineSrc which has merged TUI files from all modules
  bubbleTeaBinary = config.core.management.tui-engine.buildGoApplication {
    pname = "module-manager-tui";
    version = "1.0.0";
    src = config.core.management.tui-engine.tuiEngineSrc;  # Use tuiEngineSrc with merged files
    go = pkgs.go;  # Use the available Go version
    modules = ../gomod2nix.toml;
  #  subPackages = [ "." ];  # Build the main package
  #  nativeBuildInputs = with pkgs; [
  #    config.core.management.tui-engine.installShellFiles
  #  ];
  #  postInstall = ''
  #    installShellCompletion --cmd module-manager-tui \
  #      --bash <($out/bin/module-manager-tui completion bash) \
  #      --fish <($out/bin/module-manager-tui completion fish) \
  #      --zsh <($out/bin/module-manager-tui completion zsh)
  #  '';
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
    # Call the Go binary with the action script paths as arguments
    exec ${bubbleTeaBinary}/bin/tui-engine \
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
