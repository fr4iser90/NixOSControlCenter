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
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  isSwarmMode = (cfg.swarm or null) != null;
  virtUsers = filterAttrs (name: user: user.role == "virtualization") (getModuleConfig "user");
  adminUsers = filterAttrs (name: user: user.role == "admin") (getModuleConfig "user");
  hasVirtUsers = (length (attrNames virtUsers)) > 0;
  hasAdminUsers = (length (attrNames adminUsers)) > 0;
  virtUser =
    if hasVirtUsers then (head (attrNames virtUsers))
    else if (hasAdminUsers && !isSwarmMode) then (head (attrNames adminUsers))
    else "";

  hostDomain = systemConfig.domain or "";
  hostEmail = systemConfig.email or "";
  swarmRole = if cfg.swarm == null then "" else toString cfg.swarm;

  homelabStatus = pkgs.writeShellScriptBin "ncc-homelab-status" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    JSON=false
    for a in "$@"; do
      case "$a" in
        --json|-j) JSON=true ;;
        --help|-h)
          echo "Usage: ncc homelab status [--json]"
          exit 0
          ;;
      esac
    done

    DOCKER_INSTALLED=false
    DOCKER_RUNNING=false
    SWARM_STATUS="unknown"
    if command -v docker >/dev/null 2>&1; then
      DOCKER_INSTALLED=true
      if docker info >/dev/null 2>&1; then
        DOCKER_RUNNING=true
        if docker info 2>/dev/null | grep -q "Swarm: active"; then
          SWARM_STATUS="active"
        elif docker info 2>/dev/null | grep -q "Swarm:"; then
          SWARM_STATUS="inactive"
        fi
      else
        SWARM_STATUS="unavailable"
      fi
    else
      SWARM_STATUS="unavailable"
    fi

    DOMAIN=${lib.escapeShellArg hostDomain}
    EMAIL=${lib.escapeShellArg hostEmail}
    VIRT_USER=${lib.escapeShellArg virtUser}
    SWARM_ROLE=${lib.escapeShellArg swarmRole}

    if [[ "$JSON" == true ]]; then
      ${pkgs.jq}/bin/jq -n \
        --argjson docker_installed "$DOCKER_INSTALLED" \
        --argjson docker_running "$DOCKER_RUNNING" \
        --arg swarm_status "$SWARM_STATUS" \
        --arg swarm_role "$SWARM_ROLE" \
        --arg domain "$DOMAIN" \
        --arg email "$EMAIL" \
        --arg virt_user "$VIRT_USER" \
        '{
          docker_installed: $docker_installed,
          docker_running: $docker_running,
          swarm_status: $swarm_status,
          swarm_role: $swarm_role,
          domain: $domain,
          email: $email,
          virt_user: $virt_user
        }'
      exit 0
    fi

    echo "${ui.badges.info "Homelab Status"}"
    echo "${ui.messages.info "Homelab module is enabled"}"
    if [[ "$DOCKER_INSTALLED" == true ]]; then
      echo "${ui.tables.keyValue "Docker Status" "Available"}"
      if [[ "$DOCKER_RUNNING" == true ]]; then
        echo "${ui.tables.keyValue "Docker Daemon" "Running"}"
      else
        echo "${ui.badges.warning "Docker daemon not running"}"
      fi
    else
      echo "${ui.badges.error "Docker not installed"}"
    fi
    echo "${ui.tables.keyValue "Swarm Status" "$SWARM_STATUS"}"
    if [[ -n "$SWARM_ROLE" ]]; then
      echo "${ui.tables.keyValue "Swarm Role (config)" "$SWARM_ROLE"}"
    fi
    if [[ -n "$DOMAIN" ]]; then
      echo "${ui.tables.keyValue "Domain" "$DOMAIN"}"
    fi
    if [[ -n "$EMAIL" ]]; then
      echo "${ui.tables.keyValue "Email" "$EMAIL"}"
    fi
    if [[ -n "$VIRT_USER" ]]; then
      echo "${ui.tables.keyValue "Virt user" "$VIRT_USER"}"
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

  # Machine lines: name|status|image|ports
  homelabListContainers = pkgs.writeShellScriptBin "ncc-homelab-list-containers" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    if ! command -v docker >/dev/null 2>&1; then
      echo "error|docker not installed||" >&2
      exit 1
    fi
    if ! docker info >/dev/null 2>&1; then
      echo "error|docker daemon not running||" >&2
      exit 1
    fi
    docker ps -a --format '{{.Names}}|{{.Status}}|{{.Image}}|{{.Ports}}' 2>/dev/null || true
  '';

  # Machine lines: container|proto|host_ip|host_port|container_port
  homelabListPorts = pkgs.writeShellScriptBin "ncc-homelab-list-ports" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
      exit 0
    fi
    docker ps -q 2>/dev/null | while read -r id; do
      [[ -z "$id" ]] && continue
      name="$(docker inspect -f '{{.Name}}' "$id" 2>/dev/null | sed 's|^/||')"
      docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{range $conf}}{{printf "%s\t%s\t%s\n" $p .HostIp .HostPort}}{{end}}{{end}}{{end}}' "$id" 2>/dev/null \
        | while IFS=$'\t' read -r mapping host_ip host_port; do
            [[ -z "''${mapping:-}" ]] && continue
            container_port="''${mapping%%/*}"
            proto="''${mapping##*/}"
            echo "''${name}|''${proto}|''${host_ip}|''${host_port}|''${container_port}"
          done
    done
  '';

  # Machine lines: source|domain  (config | label:<container> | env:<container>)
  homelabListDomains = pkgs.writeShellScriptBin "ncc-homelab-list-domains" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    DOMAIN=${lib.escapeShellArg hostDomain}
    if [[ -n "$DOMAIN" ]]; then
      echo "config|$DOMAIN"
    fi
    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
      exit 0
    fi
    docker ps -q 2>/dev/null | while read -r id; do
      [[ -z "$id" ]] && continue
      name="$(docker inspect -f '{{.Name}}' "$id" 2>/dev/null | sed 's|^/||')"
      # Traefik / common Host(`…`) label values
      docker inspect -f '{{range $k, $v := .Config.Labels}}{{println $v}}{{end}}' "$id" 2>/dev/null \
        | grep -oE 'Host\(`[^`]+`\)' \
        | sed -E 's/Host\(`([^`]+)`\)/\1/' \
        | while read -r host; do
            [[ -n "$host" ]] && echo "label:''${name}|''${host}"
          done || true
      # DOMAIN / VIRTUAL_HOST env
      docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$id" 2>/dev/null \
        | while IFS= read -r line; do
            case "$line" in
              DOMAIN=*|VIRTUAL_HOST=*|TRAEFIK_HOST=*)
                val="''${line#*=}"
                [[ -n "$val" ]] && echo "env:''${name}|''${val}"
                ;;
            esac
          done || true
    done | awk -F'|' '!seen[$0]++'
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
    shift || true
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
  ncc homelab status [--json]
  ncc homelab init-swarm
  ncc homelab list-stacks
  ncc homelab list-containers
  ncc homelab list-ports
  ncc homelab list-domains
  ncc homelab manager
EOF
            ;;
        esac
        ;;
      help|-h|--help) exec "$0" ;;
      status) exec ${homelabStatus}/bin/ncc-homelab-status "$@" ;;
      init-swarm) exec ${homelabInitSwarm}/bin/ncc-homelab-init-swarm ;;
      list-stacks) exec ${homelabListStacks}/bin/ncc-homelab-list-stacks ;;
      list-containers) exec ${homelabListContainers}/bin/ncc-homelab-list-containers ;;
      list-ports) exec ${homelabListPorts}/bin/ncc-homelab-list-ports ;;
      list-domains) exec ${homelabListDomains}/bin/ncc-homelab-list-domains ;;
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
    description = "Docker Swarm, containers, ports, and domains";
    enabled = cfg.enable or false;
    group = "features";
  })
  (cliRegistry.registerGuiPage "homelab" ./ui/gui)
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
        ncc homelab status [--json]
        ncc homelab init-swarm|list-stacks|list-containers|list-ports|list-domains|manager
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
      longHelp = "ncc homelab status [--json]";
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
    {
      name = "list-containers";
      parent = "homelab";
      domain = "homelab";
      description = "List Docker containers (name|status|image|ports)";
      category = "infrastructure";
      script = "${homelabListContainers}/bin/ncc-homelab-list-containers";
      shortHelp = "list-containers - List containers";
      longHelp = "ncc homelab list-containers";
    }
    {
      name = "list-ports";
      parent = "homelab";
      domain = "homelab";
      description = "List published container ports";
      category = "infrastructure";
      script = "${homelabListPorts}/bin/ncc-homelab-list-ports";
      shortHelp = "list-ports - List published ports";
      longHelp = "ncc homelab list-ports";
    }
    {
      name = "list-domains";
      parent = "homelab";
      domain = "homelab";
      description = "List configured and discovered domains";
      category = "infrastructure";
      script = "${homelabListDomains}/bin/ncc-homelab-list-domains";
      shortHelp = "list-domains - List domains";
      longHelp = "ncc homelab list-domains";
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
