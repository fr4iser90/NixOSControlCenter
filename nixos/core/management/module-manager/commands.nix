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
    # Modules Domain Manager (TUI)
    {
      name = "modules";
      domain = "modules";
      description = "Interactive module management TUI";
      category = "system";
      script = "${moduleManagerTui}/bin/ncc-module-manager";
      type = "manager";
      permission = "system.manage";
      requiresSudo = true;
      dangerous = false;
      arguments = [];
      dependencies = [ "bubbletea" ];
      shortHelp = "modules - Module management (TUI)";
      longHelp = ''
        Interactive module management with modern Bubble Tea TUI.
        
        Usage:
          ncc modules           - Open TUI
          ncc modules enable    - Enable module (future)
          ncc modules disable   - Disable module (future)
        
        Features:
        - Runtime discovery of all available modules
        - Real-time status from config files
        - Beautiful terminal interface with advanced features
        - No rebuild required to see new modules
      '';
    }
    # Alias: module-manager -> modules
    {
      name = "module-manager";
      domain = "modules";
      description = "Module management TUI (alias)";
      category = "system";
      script = "${moduleManagerTui}/bin/ncc-module-manager";
      type = "manager";
      permission = "system.manage";
      requiresSudo = true;
      dangerous = false;
      arguments = [];
      dependencies = [ "bubbletea" ];
      shortHelp = "module-manager - Module management (TUI)";
      longHelp = ''
        Alias for:
          ncc modules

        Interactive module management with modern Bubble Tea TUI.
      '';
    }
    # Internal helper command
    {
      name = "get-module-data";
      domain = "modules";
      parent = "modules";
      internal = true;
      description = "Internal: Get module discovery data";
      category = "system";
      script = "${moduleManagerTui}/bin/ncc-module-manager";
      arguments = ["get-module-data"];
      shortHelp = "get-module-data - Internal discovery helper";
    }
    ])
  ]
