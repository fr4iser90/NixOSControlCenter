{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;

  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  tuiActions = if tuiOn then import ./ui/tui/actions.nix { inherit config lib pkgs getModuleApi; } else null;
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
  profilesStr = concatStringsSep "," (cfg.profiles or []);
  installRoot = cfg.catalog.installRoot or "";

  stacksOperator = import ./handlers/stacks-operator-scripts.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi;
  };

  catalogBin = name: ''
    VIRT=${lib.escapeShellArg virtUser}
    ROOT="/home/$VIRT"
    IR=${lib.escapeShellArg installRoot}
    [[ -n "$IR" ]] && ROOT="$ROOT/$IR"
    BIN="$ROOT/docker-scripts/bin/${name}"
    if [[ ! -x "$BIN" && ! -f "$BIN" ]]; then
      ${ui.messages.error "Catalog script missing: $BIN"}
      ${ui.messages.info "Next: ncc stacks fetch"}
      exit 1
    fi
    exec bash "$BIN" "$@"
  '';

  stacksStatus = pkgs.writeShellScriptBin "ncc-stacks-status" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    JSON=false
    for a in "$@"; do
      case "$a" in
        --json|-j) JSON=true ;;
        --help|-h)
          echo "Usage: ncc stacks status [--json]"
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
    PROFILES=${lib.escapeShellArg profilesStr}
    INSTALL_ROOT=${lib.escapeShellArg installRoot}

    CATALOG_PRESENT=false
    if [[ -n "$VIRT_USER" ]]; then
      CAT_ROOT="/home/$VIRT_USER"
      if [[ -n "$INSTALL_ROOT" ]]; then
        CAT_ROOT="$CAT_ROOT/$INSTALL_ROOT"
      fi
      if [[ -d "$CAT_ROOT/docker-scripts" || -d "$CAT_ROOT/catalog" ]]; then
        CATALOG_PRESENT=true
      fi
    fi

    if [[ "$JSON" == true ]]; then
      ${pkgs.jq}/bin/jq -n \
        --argjson docker_installed "$DOCKER_INSTALLED" \
        --argjson docker_running "$DOCKER_RUNNING" \
        --argjson catalog_present "$CATALOG_PRESENT" \
        --arg swarm_status "$SWARM_STATUS" \
        --arg swarm_role "$SWARM_ROLE" \
        --arg domain "$DOMAIN" \
        --arg email "$EMAIL" \
        --arg virt_user "$VIRT_USER" \
        --arg profiles "$PROFILES" \
        '{
          docker_installed: $docker_installed,
          docker_running: $docker_running,
          catalog_present: $catalog_present,
          swarm_status: $swarm_status,
          swarm_role: $swarm_role,
          domain: $domain,
          email: $email,
          virt_user: $virt_user,
          profiles: $profiles
        }'
      exit 0
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "Stacks Status"}
    fi
    ${ui.messages.loading "Checking Docker / Swarm…"}
    if [[ "$DOCKER_INSTALLED" == true ]]; then
      ${ui.tables.keyValue "Docker" "available"}
      if [[ "$DOCKER_RUNNING" == true ]]; then
        ${ui.tables.keyValue "Daemon" "running"}
      else
        ${ui.messages.warning "Docker daemon not running"}
      fi
    else
      ${ui.messages.error "Docker not installed (enable via packages / packageModules)"}
    fi
    ${ui.tables.keyValue "Swarm" "$SWARM_STATUS"}
    [[ -n "$SWARM_ROLE" ]] && ${ui.tables.keyValue "Swarm role (config)" "$SWARM_ROLE"}
    [[ -n "$PROFILES" ]] && ${ui.tables.keyValue "Profiles" "$PROFILES"}
    [[ -n "$DOMAIN" ]] && ${ui.tables.keyValue "Domain" "$DOMAIN"}
    [[ -n "$EMAIL" ]] && ${ui.tables.keyValue "Email" "$EMAIL"}
    [[ -n "$VIRT_USER" ]] && ${ui.tables.keyValue "Virt user" "$VIRT_USER"}
    ${ui.messages.success "Stacks status ready"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc stacks fetch   or   ncc stacks ops status"}
    fi
  '';

  stacksInitSwarmFallback = pkgs.writeShellScriptBin "ncc-stacks-swarm" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "Stacks swarm"}
    fi
    VIRT=${lib.escapeShellArg virtUser}
    ROOT="/home/$VIRT"
    IR=${lib.escapeShellArg installRoot}
    [[ -n "$IR" ]] && ROOT="$ROOT/$IR"
    BIN="$ROOT/docker-scripts/bin/swarm.sh"
    if [[ -f "$BIN" ]]; then
      exec bash "$BIN" "$@"
    fi
    case "''${1:-}" in
      init|"")
        shift || true
        ${ui.messages.loading "Initializing Docker Swarm (fallback)"}
        if docker swarm init "$@" >/dev/null 2>&1; then
          ${ui.messages.success "Swarm initialized"}
          docker swarm join-token worker
          if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
            ${ui.messages.info "Next: ncc stacks ops status"}
          fi
        else
          ${ui.messages.error "Failed to initialize Swarm"}
          exit 1
        fi
        ;;
      *)
        ${ui.messages.error "Catalog swarm.sh not found"}
        ${ui.messages.info "Next: ncc stacks fetch"}
        exit 1
        ;;
    esac
  '';

  stacksListStacks = pkgs.writeShellScriptBin "ncc-stacks-list-stacks" ''
    #!${pkgs.bash}/bin/bash
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "Docker Stacks"}
    fi
    ${ui.messages.loading "Listing Docker stacks…"}
    if docker stack ls >/dev/null 2>&1; then
      docker stack ls --format "table {{.Name}}\t{{.Services}}"
      ${ui.messages.success "Stack list ready"}
    else
      ${ui.messages.error "Cannot list stacks — check Docker/Swarm"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc stacks status"}
      fi
      exit 1
    fi
  '';

  stacksListContainers = pkgs.writeShellScriptBin "ncc-stacks-list-containers" ''
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

  stacksListPorts = pkgs.writeShellScriptBin "ncc-stacks-list-ports" ''
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

  stacksListDomains = pkgs.writeShellScriptBin "ncc-stacks-list-domains" ''
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
      docker inspect -f '{{range $k, $v := .Config.Labels}}{{println $v}}{{end}}' "$id" 2>/dev/null \
        | grep -oE 'Host\(`[^`]+`\)' \
        | sed -E 's/Host\(`([^`]+)`\)/\1/' \
        | while read -r host; do
            [[ -n "$host" ]] && echo "label:''${name}|''${host}"
          done || true
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

  stacksOps = pkgs.writeShellScriptBin "ncc-stacks-ops" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    ${catalogBin "stacks.sh"}
  '';

  stacksEntry = pkgs.writeShellScriptBin "ncc-stacks" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) _ui=tui ;;
        gui|tui) echo "Use: ncc stacks --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    cmd="''${1:-}"
    shift || true
    case "$cmd" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui stacks'' else guiOff} ;;
          tui)
            echo "Use: ncc stacks manager   or enable tui-engine" >&2
            exit 2
            ;;
          *)
            cat <<EOF
ncc stacks — Homelab + compute catalog (CLI)

Usage:
  ncc stacks                 Help
  ncc stacks --gui           Domain GUI
  ncc stacks status [--json]
  ncc stacks fetch           Clone/update catalog (as virt user)
  ncc stacks list-profiles   Compatible profiles (use --remote to browse without fetch)
  ncc stacks list-catalog    Individual catalog services (group/service)
  ncc stacks install …       --profile NAME  or  group/service
  ncc stacks init […]        init-homelab / init-compute (--profile …)
  ncc stacks ops …           stacks.sh status|start|stop|restart
  ncc stacks swarm …         swarm.sh (homelab family)
  ncc stacks list-stacks|list-containers|list-ports|list-domains
  ncc stacks manager         TUI
EOF
            ;;
        esac
        ;;
      help|-h|--help) exec "$0" ;;
      status) exec ${stacksStatus}/bin/ncc-stacks-status "$@" ;;
      fetch)
        if command -v ncc-stacks-fetch >/dev/null 2>&1; then
          exec ncc-stacks-fetch "$@"
        else
          ${ui.messages.error "ncc-stacks-fetch not installed (enable stack-manager)"}
          exit 1
        fi
        ;;
      list-profiles)
        if command -v ncc-stacks-list-profiles >/dev/null 2>&1; then
          exec ncc-stacks-list-profiles "$@"
        else
          ${ui.messages.error "ncc-stacks-list-profiles not installed (enable stack-manager)"}
          exit 1
        fi
        ;;
      list-catalog)
        if command -v ncc-stacks-list-catalog >/dev/null 2>&1; then
          exec ncc-stacks-list-catalog "$@"
        else
          ${ui.messages.error "ncc-stacks-list-catalog not installed (enable stack-manager)"}
          exit 1
        fi
        ;;
      install)
        if command -v ncc-stacks-install >/dev/null 2>&1; then
          exec ncc-stacks-install "$@"
        else
          ${ui.messages.error "ncc-stacks-install not installed (enable stack-manager)"}
          exit 1
        fi
        ;;
      init|create)
        if command -v ncc-stacks-init >/dev/null 2>&1; then
          exec ncc-stacks-init "$@"
        else
          ${ui.messages.error "ncc-stacks-init not installed"}
          exit 1
        fi
        ;;
      ops) exec ${stacksOps}/bin/ncc-stacks-ops "$@" ;;
      swarm) exec ${stacksInitSwarmFallback}/bin/ncc-stacks-swarm "$@" ;;
      init-swarm) exec ${stacksInitSwarmFallback}/bin/ncc-stacks-swarm init "$@" ;;
      list-stacks) exec ${stacksListStacks}/bin/ncc-stacks-list-stacks ;;
      list-containers) exec ${stacksListContainers}/bin/ncc-stacks-list-containers ;;
      list-ports) exec ${stacksListPorts}/bin/ncc-stacks-list-ports ;;
      list-domains) exec ${stacksListDomains}/bin/ncc-stacks-list-domains ;;
      manager)
        ${if tuiOn then ''exec ${tuiActions}/bin/homelab-tui-actions menu'' else tuiOff}
        ;;
      *)
        ${ui.messages.error "Unknown: ncc stacks $cmd"}
        ${ui.messages.info "Next: ncc stacks  (help)"}
        exit 1
        ;;
    esac
  '';

  childCmds = [
    {
      name = "status";
      parent = "stacks";
      domain = "stacks";
      description = "Show stack / Docker status";
      category = "infrastructure";
      script = "${stacksStatus}/bin/ncc-stacks-status";
      shortHelp = "status - Show status";
      longHelp = "ncc stacks status [--json]";
    }
    {
      name = "fetch";
      parent = "stacks";
      domain = "stacks";
      description = "Fetch stack catalog from git";
      category = "infrastructure";
      script = "${pkgs.writeShellScriptBin "ncc-stacks-fetch-cmd" ''
        exec ncc-stacks-fetch "$@"
      ''}/bin/ncc-stacks-fetch-cmd";
      shortHelp = "fetch - Clone/update catalog";
      longHelp = "ncc stacks fetch  (run as virt user)";
    }
    {
      name = "init";
      parent = "stacks";
      domain = "stacks";
      description = "Init profiles (homelab or compute)";
      category = "infrastructure";
      script = "${pkgs.writeShellScriptBin "ncc-stacks-init-cmd" ''
        exec ncc-stacks-init "$@"
      ''}/bin/ncc-stacks-init-cmd";
      shortHelp = "init - Run catalog installer";
      longHelp = "ncc stacks init [--profile NAME …]";
    }
    {
      name = "fleet-tags";
      parent = "stacks";
      domain = "stacks";
      description = "Declarative fleet host tags from systemConfig";
      category = "infrastructure";
      script = "${stacksOperator.stacksFleetTags}/bin/ncc-stacks-fleet-tags";
      arguments = [ "--json" ];
      shortHelp = "fleet-tags - Declarative fleet labels (JSON)";
      longHelp = ''
        Read stack-manager.fleetTags from systemConfig (creds key user@host).

        Examples:
          ncc stacks fleet-tags
          ncc stacks fleet-tags --json
      '';
    }
    {
      name = "dns-env";
      parent = "stacks";
      domain = "stacks";
      description = "Write Cloudflare DNS env for homelab gateway";
      category = "infrastructure";
      script = "${stacksOperator.stacksDnsEnv}/bin/ncc-stacks-dns-env";
      arguments = [ "--cf-email=" "--cf-token=" "--json" ];
      shortHelp = "dns-env - Write ddns-updater.env (virt user)";
      longHelp = ''
        Write catalog/gateway/ddns-updater/ddns-updater.env on the Target.

        Examples:
          sudo -u <virt> ncc stacks dns-env --cf-email=you@mail.com --cf-token=TOKEN
          ncc stacks dns-env --json   # stdin: {"cfEmail":"…","cfToken":"…"}
      '';
    }
    {
      name = "list-profiles";
      parent = "stacks";
      domain = "stacks";
      description = "List catalog profiles for this host";
      category = "infrastructure";
      script = "${pkgs.writeShellScriptBin "ncc-stacks-list-profiles-cmd" ''
        exec ncc-stacks-list-profiles "$@"
      ''}/bin/ncc-stacks-list-profiles-cmd";
      shortHelp = "list-profiles - Compatible profiles";
      longHelp = "ncc stacks list-profiles [--remote] [--all] [--plain] [-v]";
    }
    {
      name = "list-catalog";
      parent = "stacks";
      domain = "stacks";
      description = "List individual catalog services";
      category = "infrastructure";
      script = "${pkgs.writeShellScriptBin "ncc-stacks-list-catalog-cmd" ''
        exec ncc-stacks-list-catalog "$@"
      ''}/bin/ncc-stacks-list-catalog-cmd";
      shortHelp = "list-catalog - Catalog group/service list";
      longHelp = "ncc stacks list-catalog [--remote] [--family homelab|compute] [--plain] [-v]";
    }
    {
      name = "install";
      parent = "stacks";
      domain = "stacks";
      description = "Install profile bundle or single catalog service";
      category = "infrastructure";
      script = "${pkgs.writeShellScriptBin "ncc-stacks-install-cmd" ''
        exec ncc-stacks-install "$@"
      ''}/bin/ncc-stacks-install-cmd";
      shortHelp = "install - Profile or group/service";
      longHelp = "ncc stacks install --profile NAME | group/service";
    }
    {
      name = "ops";
      parent = "stacks";
      domain = "stacks";
      description = "Day-2 stack ops (status/start/stop/restart)";
      category = "infrastructure";
      script = "${stacksOps}/bin/ncc-stacks-ops";
      shortHelp = "ops - stacks.sh wrapper";
      longHelp = "ncc stacks ops status|start|stop|restart [--profile …]";
    }
    {
      name = "swarm";
      parent = "stacks";
      domain = "stacks";
      description = "Swarm helpers (homelab family)";
      category = "infrastructure";
      script = "${stacksInitSwarmFallback}/bin/ncc-stacks-swarm";
      shortHelp = "swarm - swarm.sh wrapper";
      longHelp = "ncc stacks swarm init|deploy|status|…";
    }
    {
      name = "list-stacks";
      parent = "stacks";
      domain = "stacks";
      description = "List Docker stacks";
      category = "infrastructure";
      script = "${stacksListStacks}/bin/ncc-stacks-list-stacks";
      shortHelp = "list-stacks - List Swarm stacks";
      longHelp = "ncc stacks list-stacks";
    }
    {
      name = "list-containers";
      parent = "stacks";
      domain = "stacks";
      description = "List Docker containers";
      category = "infrastructure";
      script = "${stacksListContainers}/bin/ncc-stacks-list-containers";
      shortHelp = "list-containers - List containers";
      longHelp = "ncc stacks list-containers";
    }
    {
      name = "list-ports";
      parent = "stacks";
      domain = "stacks";
      description = "List published ports";
      category = "infrastructure";
      script = "${stacksListPorts}/bin/ncc-stacks-list-ports";
      shortHelp = "list-ports - List ports";
      longHelp = "ncc stacks list-ports";
    }
    {
      name = "list-domains";
      parent = "stacks";
      domain = "stacks";
      description = "List domains";
      category = "infrastructure";
      script = "${stacksListDomains}/bin/ncc-stacks-list-domains";
      shortHelp = "list-domains - List domains";
      longHelp = "ncc stacks list-domains";
    }
  ] ++ optionals tuiOn [
    {
      name = "manager";
      parent = "stacks";
      domain = "stacks";
      type = "manager";
      description = "Stacks TUI";
      category = "infrastructure";
      script = "${pkgs.writeShellScriptBin "ncc-stacks-manager" ''
        exec ${tuiActions}/bin/homelab-tui-actions menu
      ''}/bin/ncc-stacks-manager";
      shortHelp = "manager - Interactive TUI";
      longHelp = "ncc stacks manager";
    }
  ];
in
mkMerge [
  (cliRegistry.registerGuiDomain "stacks" {
    label = "Stacks";
    description = "Homelab + compute Docker catalog (profiles, Swarm, containers)";
    enabled = cfg.enable or false;
    group = "features";
  })
  (cliRegistry.registerGuiPage "stacks" ./ui/gui)
  (mkIf (cfg.enable or false) (cliRegistry.registerCommandsFor "stacks" (
    [
      {
        name = "stacks";
        domain = "stacks";
        type = "manager";
        description = "Stack catalog management (homelab + compute)";
        category = "infrastructure";
        script = "${stacksEntry}/bin/ncc-stacks";
        shortHelp = "stacks - Homelab + compute stacks";
        longHelp = ''
          ncc stacks --gui
          ncc stacks status|fetch|init|ops|swarm|…
        '';
      }
    ] ++ childCmds
  )))
]
