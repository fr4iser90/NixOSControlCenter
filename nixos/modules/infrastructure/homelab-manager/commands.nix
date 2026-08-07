{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;

  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;

  tuiActions = if tuiOn then import ./ui/tui/actions.nix { inherit config lib pkgs; } else null;
  domainGui = (getModuleApi "gui-engine").domainGui pkgs;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  homelabStatus = pkgs.writeShellScriptBin "ncc-homelab-status" ''
    #!${pkgs.bash}/bin/bash
    echo "${ui.badges.info "Homelab Status"}"
    echo "${ui.messages.info "Homelab module is enabled"}"

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

    if docker info 2>/dev/null | grep -q "Swarm: active"; then
      echo "${ui.tables.keyValue "Swarm Status" "Active"}"
    elif docker info 2>/dev/null | grep -q "Swarm:"; then
      echo "${ui.tables.keyValue "Swarm Status" "Inactive"}"
    fi
  '';

  homelabInitSwarm = pkgs.writeShellScriptBin "ncc-homelab-init-swarm" ''
    #!${pkgs.bash}/bin/bash
    echo "${ui.badges.info "Initializing Docker Swarm"}"
    if docker swarm init >/dev/null 2>&1; then
      echo "${ui.badges.success "Swarm initialized successfully"}"
      docker swarm join-token worker
    else
      echo "${ui.badges.error "Failed to initialize Swarm"}"
    fi
  '';

  homelabListStacks = pkgs.writeShellScriptBin "ncc-homelab-list-stacks" ''
    #!${pkgs.bash}/bin/bash
    echo "${ui.badges.info "Docker Stacks"}"
    if docker stack ls >/dev/null 2>&1; then
      docker stack ls --format "table {{.Name}}\t{{.Services}}"
    else
      echo "${ui.badges.error "Cannot list stacks - check Docker/Swarm status"}"
    fi
  '';

  homelabEntry = pkgs.writeShellScriptBin "ncc-homelab" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) _ui=tui ;;
        gui|tui) echo "Use: ncc homelab --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    cmd="''${1:-}"
    case "$cmd" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui homelab'' else guiOff} ;;
          tui)
            echo "Use: ncc homelab manager   or enable tui-engine" >&2
            exit 2
            ;;
          *)
            cat <<EOF
ncc homelab — Homelab management (CLI)

Usage:
  ncc homelab                 Help
  ncc homelab --gui           Domain GUI
  ncc homelab status
  ncc homelab init-swarm
  ncc homelab list-stacks
  ncc homelab manager
EOF
            ;;
        esac
        ;;
      help|-h|--help) exec "$0" ;;
      status) exec ${homelabStatus}/bin/ncc-homelab-status ;;
      init-swarm) exec ${homelabInitSwarm}/bin/ncc-homelab-init-swarm ;;
      list-stacks) exec ${homelabListStacks}/bin/ncc-homelab-list-stacks ;;
      manager)
        ${if tuiOn then ''exec ${tuiActions}/bin/homelab-tui-actions menu'' else tuiOff}
        ;;
      *)
        echo "Unknown: ncc homelab $cmd" >&2
        exit 1
        ;;
    esac
  '';

in
mkMerge [
  (cliRegistry.registerGuiDomain "homelab" {
    label = "Homelab";
    description = "Docker Swarm and stacks";
    enabled = cfg.enable or false;
  })
  (mkIf (cfg.enable or false) (cliRegistry.registerCommandsFor "homelab" (
    [
    {
      name = "homelab";
      domain = "homelab";
      type = "manager";
      description = "Homelab management";
      category = "infrastructure";
      script = "${homelabEntry}/bin/ncc-homelab";
      shortHelp = "homelab - Homelab";
      longHelp = ''
        ncc homelab                 CLI help
        ncc homelab --gui
        ncc homelab status|init-swarm|list-stacks|manager
      '';
    }
    {
      name = "status";
      parent = "homelab";
      domain = "homelab";
      description = "Show homelab status";
      category = "infrastructure";
      script = "${homelabStatus}/bin/ncc-homelab-status";
      shortHelp = "status - Show homelab status";
      longHelp = "ncc homelab status";
    }
    {
      name = "init-swarm";
      parent = "homelab";
      domain = "homelab";
      description = "Initialize Docker Swarm";
      category = "infrastructure";
      script = "${homelabInitSwarm}/bin/ncc-homelab-init-swarm";
      shortHelp = "init-swarm - Initialize Docker Swarm";
      longHelp = "ncc homelab init-swarm";
    }
    {
      name = "list-stacks";
      parent = "homelab";
      domain = "homelab";
      description = "List Docker stacks";
      category = "infrastructure";
      script = "${homelabListStacks}/bin/ncc-homelab-list-stacks";
      shortHelp = "list-stacks - List Docker stacks";
      longHelp = "ncc homelab list-stacks";
    }
  ]
  ++ optionals tuiOn [
    {
      name = "manager";
      parent = "homelab";
      domain = "homelab";
      type = "manager";
      description = "Homelab TUI";
      category = "infrastructure";
      script = "${pkgs.writeShellScriptBin "ncc-homelab-manager" ''
        exec ${tuiActions}/bin/homelab-tui-actions menu
      ''}/bin/ncc-homelab-manager";
      shortHelp = "manager - Interactive homelab TUI";
      longHelp = "ncc homelab manager";
    }
  ]
  )))
]
