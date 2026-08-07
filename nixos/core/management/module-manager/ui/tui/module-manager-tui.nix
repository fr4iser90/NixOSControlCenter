{ config, lib, pkgs, getModuleApi, getModuleConfig, getModuleMetadata, ... }:

with lib;

let
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiNix = (getModuleApi "tui-engine").fromConfig config;
  tuiMeta = getModuleMetadata "tui-engine";

  runtimeDiscovery = (import ../../lib/runtime_discovery.nix { inherit lib pkgs; }).runtimeDiscovery;
  moduleManagerPath = ../..;

  bubbleTeaBinary = tuiNix.createTuiBinary {
    modulePath = moduleManagerPath;
    moduleName = "module-manager";
  };

  runtimeDiscoveryScript = pkgs.writeScript "runtime-discovery" ''
    #!${pkgs.bash}/bin/bash
    ${runtimeDiscovery}
  '';

  actionScripts = {
    getModuleList = pkgs.writeScript "get-module-list" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
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

  moduleManagerTuiScript = pkgs.writeScriptBin "ncc-module-manager-tui" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    exec ${bubbleTeaBinary}/bin/module-manager-tui \
      "${actionScripts.getModuleList}" \
      "${actionScripts.getFilterPanel}" \
      "${actionScripts.getDetailsPanel}" \
      "${actionScripts.getActionsPanel}"
  '';

in
mkIf tuiOn {
  environment.systemPackages = [ moduleManagerTuiScript ];
  ${tuiMeta.configPath}.moduleManagerTuiScript = moduleManagerTuiScript;
}
