{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";

  # Pass discovery script as string to avoid ncc permission issues
  discoveryScript = (import ./lib/runtime_discovery.nix { inherit lib pkgs; }).runtimeDiscovery;

  # Bubble Tea TUI from tui-engine - use script from config like SSH manager
  bubbleTeaTui = config.core.management.tui-engine.moduleManagerTuiScript;

  # Gum Module Manager (SINGLE INTERFACE with subcommands)
  moduleManagerTui = pkgs.writeScriptBin "ncc-module-manager" ''
    # Handle subcommands
    case "$1" in
      "get-module-data")
        # Execute the discovery script
        ${(import ./lib/runtime_discovery.nix { inherit lib pkgs; }).runtimeDiscovery}
        ;;
      "")
        # No args = run TUI
        ${bubbleTeaTui}/bin/ncc-module-manager-tui
        ;;
      *)
        echo "Usage: ncc module-manager [get-module-data]"
        exit 1
        ;;
    esac
  '';


in
  lib.mkMerge [
    # PRIMARY: Bubble Tea module manager (ONLY INTERFACE)
    (cliRegistry.registerCommandsFor "module-manager" [
    {
      name = "module-manager";
      description = "Interactive module management TUI";
      category = "system";
      script = "${moduleManagerTui}/bin/ncc-module-manager";
      type = "manager";
      permission = "system.manage";
      requiresSudo = true;
      dangerous = false;
      arguments = [];
      dependencies = [ "bubbletea" ];
      shortHelp = "module-manager - Toggle NixOS modules";
      longHelp = ''
        Interactive module management with modern Bubble Tea TUI.
        Runtime discovery of all available modules.
        Real-time status from config files.
        Beautiful terminal interface with advanced features.
        No rebuild required to see new modules.
      '';
    }
    ])
  ]
