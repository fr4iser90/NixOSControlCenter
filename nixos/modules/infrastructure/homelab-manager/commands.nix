{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, moduleName, ... }:

with lib;

let
  # Get module config and metadata
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  cfg = systemConfig.${metadata.configPath}; # Dynamisch aus metadata!

  # Get UI utilities
  ui = getModuleApi "cli-formatter";

  # TUI Actions script
  tuiActions = import ./tui/actions.nix { inherit config lib pkgs; };

  # Basic CLI commands (placeholder implementations)
  homelabStatus = pkgs.writeShellScriptBin "ncc-homelab-status" ''
    #!${pkgs.bash}/bin/bash
    echo "${ui.badges.info "🏠 Homelab Status"}"
    echo "${ui.messages.info "Homelab module is enabled"}"

    # Check Docker status
    if command -v docker >/dev/null 2>&1; then
      echo "${ui.tables.keyValue "Docker Status" "Available"}"
      if docker info >/dev/null 2>&1; then
        echo "${ui.tables.keyValue "Docker Daemon" "Running"}"
      else
        echo "${ui.badges.warning "Docker daemon not running"}"
      fi
    else
      echo "${ui.badges.error "Docker not installed"}"
    fi

    # Check Swarm status
    if docker info 2>/dev/null | grep -q "Swarm:"; then
      if docker info 2>/dev/null | grep -q "Swarm: active"; then
        echo "${ui.tables.keyValue "Swarm Status" "Active"}"
        echo "${ui.tables.keyValue "Node Role" "$(docker info 2>/dev/null | grep "NodeID:" | head -1 | cut -d: -f2 | xargs)"}"
      else
        echo "${ui.tables.keyValue "Swarm Status" "Inactive"}"
      fi
    fi
  '';

  homelabInitSwarm = pkgs.writeShellScriptBin "ncc-homelab-init-swarm" ''
    #!${pkgs.bash}/bin/bash
    echo "${ui.badges.info "🚀 Initializing Docker Swarm"}"

    if docker swarm init >/dev/null 2>&1; then
      echo "${ui.badges.success "Swarm initialized successfully"}"
      echo "${ui.messages.info "This node is now the Swarm manager"}"
      docker swarm join-token worker
    else
      echo "${ui.badges.error "Failed to initialize Swarm"}"
      echo "${ui.messages.info "Check if Docker is running and no existing Swarm exists"}"
    fi
  '';

  homelabListStacks = pkgs.writeShellScriptBin "ncc-homelab-list-stacks" ''
    #!${pkgs.bash}/bin/bash
    echo "${ui.badges.info "📋 Docker Stacks"}"

    if docker stack ls >/dev/null 2>&1; then
      docker stack ls --format "table {{.Name}}\t{{.Services}}"
    else
      echo "${ui.badges.error "Cannot list stacks - check Docker/Swarm status"}"
    fi
  '';

in
mkIf (cfg.enable or false) {
  # Register CLI commands
  core.management.system-manager.submodules.cli-registry.commands = [
    {
      name = "homelab-status";
      description = "Show homelab status and configuration";
      category = "infrastructure";
      script = "${homelabStatus}/bin/ncc-homelab-status";
      arguments = [];
      dependencies = [ "docker" ];
      shortHelp = "homelab-status - Show homelab status";
      longHelp = ''
        Display current homelab status including:
        - Docker daemon status
        - Swarm status and role
        - Basic system information
      '';
    }
    {
      name = "homelab-init-swarm";
      description = "Initialize Docker Swarm as manager";
      category = "infrastructure";
      script = "${homelabInitSwarm}/bin/ncc-homelab-init-swarm";
      arguments = [];
      dependencies = [ "docker" ];
      shortHelp = "homelab-init-swarm - Initialize Docker Swarm";
      longHelp = ''
        Initialize a new Docker Swarm on this node as the manager.

        This will:
        - Create a new Swarm
        - Make this node the manager
        - Generate join tokens for worker nodes

        Requirements:
        - Docker must be running
        - No existing Swarm should be active
      '';
      dangerous = false; # Not dangerous, just setup
    }
    {
      name = "homelab-list-stacks";
      description = "List all deployed Docker stacks";
      category = "infrastructure";
      script = "${homelabListStacks}/bin/ncc-homelab-list-stacks";
      arguments = [];
      dependencies = [ "docker" ];
      shortHelp = "homelab-list-stacks - List Docker stacks";
      longHelp = ''
        Display all currently deployed Docker stacks and their status.

        Shows:
        - Stack name
        - Number of services in each stack
      '';
    }
    {
      name = "homelab-manager";
      description = "Interactive homelab management TUI";
      category = "infrastructure";
      script = "${tuiActions}/bin/homelab-tui-actions";
      arguments = [ "menu" ]; # Start with main menu
      dependencies = [ "fzf" "docker" ];
      shortHelp = "homelab-manager - Interactive homelab TUI";
      longHelp = ''
        Launch the interactive Homelab Manager TUI using fzf.

        Features:
        - Initialize/join Docker Swarms
        - Deploy and manage stacks
        - Monitor services and logs
        - Configure homelab settings

        Requirements:
        - fzf must be installed
        - Docker must be available
      '';
      type = "manager"; # TUI command
    }
  ];

  # Expose TUI actions for internal use
  ${metadata.configPath}.tuiActions = tuiActions;
}
