# Builds ncc-assistant binaries (GUI chat + MCP + agent + tray) and config facade helper.
{ pkgs, lib, cfg, getModuleApi, getModuleMetadata }:

let
  ui = getModuleApi "cli-formatter";
  facade = import "${(getModuleMetadata "system-manager").path}/lib/config-facade.nix" {
    inherit pkgs;
  };

  aiKnowledgeSrc = ./doc/ai-knowledge.md;

  guiEngine = (getModuleApi "gui-engine").package pkgs;

  domainAi = import ./lib/discover-domain-ai.nix {
    inherit lib pkgs getModuleMetadata;
  };

  modulesIndex = import ./lib/discover-modules-index.nix {
    inherit lib pkgs getModuleMetadata;
  };

    appRoot = pkgs.runCommand "ncc-assistant-src" { } ''
    mkdir -p $out
    cp -r ${./python/ncc_assistant} $out/ncc_assistant
    cp -r ${./prompts} $out/prompts
    # Knowledge = ONLY discovered <module>/ai/ packs. Module inventory is live via ncc.
    mkdir -p $out/knowledge
    cp -a ${domainAi.knowledgeRoot}/. $out/knowledge/
    # Principles-only doc + generated inventory note (docs; list_modules does not read this)
    {
      cat ${aiKnowledgeSrc}
      echo
      echo "---"
      echo
      cat ${modulesIndex.inventoryFile}
    } > $out/AI_KNOWLEDGE.md
    cp -r ${guiEngine.src}/ncc_gui $out/ncc_gui
  '';

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    mcp
    httpx
    pyside6
  ]);

  configHelper = pkgs.writeShellScriptBin "ncc-assistant-config" ''
    set -euo pipefail
    NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
    ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
    export NIXOS_ROOT="$NIXOS_DIR"
    export CONFIGS_BASE="$NIXOS_DIR/systemConfig"
    export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

    ncc_cli_header() {
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.text.header "$*"}
      fi
    }
    ncc_cli_next() {
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: $*"}
      fi
    }

    usage() {
      ${ui.messages.error "Usage: ncc-assistant-config read|write|validate …"}
      ${ui.messages.info "  read <module_path>"}
      ${ui.messages.info "  write <module_path>   # content on stdin"}
      ${ui.messages.info "  validate               # Nix fragment on stdin"}
      exit 2
    }

    cmd="''${1:-}"
    case "$cmd" in
      read)
        [[ $# -ge 2 ]] || usage
        ncc_cli_header "NCC Assistant Config"
        ${ui.messages.loading "Reading module config…"}
        ncc_read_module_config "$2"
        ${ui.messages.success "Read $2"}
        ncc_cli_next "ncc-assistant-config write $2"
        ;;
      write)
        [[ $# -ge 2 ]] || usage
        ncc_cli_header "NCC Assistant Config"
        ${ui.messages.loading "Writing module config…"}
        content=$(cat)
        ncc_write_module_config "$2" "$content"
        ${ui.messages.success "Wrote $2"}
        ncc_cli_next "ncc-assistant-config read $2"
        ;;
      validate)
        ncc_cli_header "NCC Assistant Config"
        ${ui.messages.loading "Validating Nix fragment…"}
        content=$(cat)
        if ${pkgs.nix}/bin/nix-instantiate --parse -E "$content" >/dev/null 2>&1; then
          echo "valid"
          ${ui.messages.success "Fragment is valid"}
          ncc_cli_next "ncc ai"
          exit 0
        fi
        if ${pkgs.nix}/bin/nix-instantiate --eval --strict -E "$content" >/dev/null 2>&1; then
          echo "valid"
          ${ui.messages.success "Fragment is valid"}
          ncc_cli_next "ncc ai"
          exit 0
        fi
        ${ui.messages.error "Invalid Nix fragment"}
        ncc_cli_next "fix the fragment, then: ncc-assistant-config validate"
        exit 1
      ;;
      *)
        usage
        ;;
    esac
  '';

  resolvedApi =
    let
      raw = cfg.api or null;
      legacy = cfg.provider or null;
      pick =
        if raw != null && raw != "" then raw
        else if legacy != null then legacy
        else "openai-compatible";
    in
      if pick == "ollama" || pick == "openai" then "openai-compatible"
      else pick;

  mcpServersJson = builtins.toJSON (cfg.tools.mcpServers or { });

  mcpServersFile = pkgs.writeText "mcp-servers.json" mcpServersJson;

  schedulesJson = builtins.toJSON (cfg.agent.schedules or { });

  hostProfilesJson = builtins.toJSON (cfg.profiles or { });

  envExports = ''
    export NCC_ASSISTANT_ROOT="${appRoot}"
    export NCC_KNOWLEDGE_ROOT="${appRoot}/knowledge"
    export NCC_PROMPTS_ROOT="${appRoot}/prompts"
    export NCC_ASSISTANT_CONFIG_BIN="${configHelper}/bin/ncc-assistant-config"
    export NCC_ASSISTANT_API="${resolvedApi}"
    export NCC_ASSISTANT_ENDPOINT="${cfg.endpoint or "http://localhost:11434/v1"}"
    ${lib.optionalString ((cfg.model or null) != null) ''
      export NCC_ASSISTANT_MODEL="${cfg.model}"
    ''}
    ${lib.optionalString ((cfg.maxTokens or null) != null) ''
      export NCC_ASSISTANT_MAX_TOKENS="${toString cfg.maxTokens}"
    ''}
    ${lib.optionalString ((cfg.temperature or null) != null) ''
      export NCC_ASSISTANT_TEMPERATURE="${toString cfg.temperature}"
    ''}
    export NCC_ASSISTANT_ALLOW_WRITE="${if (cfg.allowWrite or true) then "1" else "0"}"
    export NCC_ASSISTANT_MCP_ALLOW_WRITE="${if (cfg.mcpAllowWrite or false) then "1" else "0"}"
    export NCC_ASSISTANT_ALLOW_REBUILD="${if (cfg.allowRebuild or false) then "1" else "0"}"
    ${lib.optionalString ((cfg.apiKeyFile or null) != null) ''
      export NCC_ASSISTANT_API_KEY_FILE="${cfg.apiKeyFile}"
    ''}
    ${lib.optionalString ((cfg.apiHeaderName or null) != null) ''
      export NCC_ASSISTANT_API_HEADER_NAME="${cfg.apiHeaderName}"
    ''}

    # Tools configuration
    export NCC_ASSISTANT_ALLOW_SHELL="${if (cfg.tools.allowShell or false) then "1" else "0"}"
    export NCC_ASSISTANT_SHELL_ALLOWLIST="${lib.concatStringsSep ":" (cfg.tools.shellAllowlist or [])}"
    export NCC_ASSISTANT_MCP_SERVERS_JSON='${mcpServersJson}'
    export NCC_ASSISTANT_MCP_SERVERS_FILE="${mcpServersFile}"

    # Per-module ai/ tools (build-time discovery). Drop inherited stub JSON.
    unset NCC_ASSISTANT_DOMAIN_TOOLS_JSON || true
    export NCC_ASSISTANT_DOMAIN_TOOLS_FILE="${domainAi.indexFile}"

    # Agent configuration
    export AGENT_ENABLE="${if (cfg.agent.enable or true) then "1" else "0"}"
    export AGENT_MAX_STEPS="${toString (cfg.agent.maxSteps or 24)}"
    export AGENT_TIMEOUT_SEC="${toString (cfg.agent.timeoutSec or 1800)}"
    export AGENT_ALLOW_WRITE="${if (cfg.agent.allowWrite or false) then "1" else "0"}"
    export AGENT_ALLOW_REBUILD="${if (cfg.agent.allowRebuild or false) then "1" else "0"}"
    export AGENT_CONFIRM="${cfg.agent.confirm or "writes"}"
    export AGENT_DRY_RUN="${if (cfg.agent.dryRun or false) then "1" else "0"}"
    ${lib.optionalString ((cfg.agent.profile or null) != null) ''
      export AGENT_PROFILE="${cfg.agent.profile}"
    ''}
    export AGENT_REQUIRE_PREFLIGHT="${if (cfg.agent.requirePreflightBeforeRebuild or false) then "1" else "0"}"

    # Agent notifications (both naming conventions)
    export NOTIFY_ENABLE="${if (cfg.agent.notifications.enable or true) then "1" else "0"}"
    export NCC_ASSISTANT_NOTIFY_ENABLE="${if (cfg.agent.notifications.enable or true) then "1" else "0"}"
    export NOTIFY_TIMEOUT_SEC="${toString (cfg.agent.notifications.timeoutSec or 300)}"
    export NCC_ASSISTANT_NOTIFY_TIMEOUT_SEC="${toString (cfg.agent.notifications.timeoutSec or 300)}"
    export NOTIFY_ON_TIMEOUT="${cfg.agent.notifications.onTimeout or "block"}"
    export NCC_ASSISTANT_NOTIFY_ON_TIMEOUT="${cfg.agent.notifications.onTimeout or "block"}"
    export NOTIFY_ON_SCHEDULE_START="${if (cfg.agent.notifications.notifyOnScheduleStart or false) then "1" else "0"}"
    export NOTIFY_ON_JOB_END="${if (cfg.agent.notifications.notifyOnJobEnd or true) then "1" else "0"}"

    # Agent tray / companion
    export AGENT_TRAY_ENABLE="${if (cfg.agent.tray.enable or false) then "1" else "0"}"
    export AGENT_COMPANION_ENABLE="${if (cfg.agent.companion.enable or false) then "1" else "0"}"

    # Swappable coding harness (native | qwen | dsh)
    export NCC_ASSISTANT_HARNESS="${cfg.agent.harness or "native"}"
    export NCC_ASSISTANT_CODING_HARNESS="${cfg.agent.codingHarness or "auto"}"

    # Schedules + host profiles (for UI / rebuild guards)
    export NCC_ASSISTANT_SCHEDULES_JSON='${schedulesJson}'
    export NCC_ASSISTANT_HOST_PROFILES_JSON='${hostProfilesJson}'

    export PYTHONPATH="${appRoot}''${PYTHONPATH:+:$PYTHONPATH}"
    export PATH="${configHelper}/bin:${nccFocusNetblock}/bin:${pkgs.jq}/bin:${pkgs.nix}/bin:$PATH"
    # Qt/Plasma: use system platform theme when available
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
  '';

  envFile = pkgs.writeText "ncc-assistant-env.sh" envExports;

  nccAssistant = pkgs.writeShellScriptBin "ncc-assistant" ''
    set -euo pipefail
    ${envExports}

    # Nix-facing entry owns §3 skeleton. Python (chat/agent/tools) prints plain;
    # see CLI.md — secondary surface.
    cmd="''${1:-}"
    interactive=0
    case "$cmd" in
      ""|gui|chat|cli|mcp|tray|companion|serve-openapi|help|-h|--help) interactive=1 ;;
    esac

    if [ -z "''${NCC_CLI_NESTED:-}" ] && [ "$cmd" != "mcp" ]; then
      ${ui.text.header "NCC AI Assistant"}
    fi

    # Long-running / interactive / binary protocols: hand off (no trailing Next)
    if [ "$interactive" -eq 1 ]; then
      if [ -z "''${NCC_CLI_NESTED:-}" ] && [ "$cmd" != "mcp" ]; then
        case "$cmd" in
          ""|gui) ${ui.messages.loading "Starting GUI…"} ;;
          chat|cli) ${ui.messages.loading "Starting chat…"} ;;
          tray) ${ui.messages.loading "Starting tray…"} ;;
          companion) ${ui.messages.loading "Starting companion…"} ;;
          serve-openapi) ${ui.messages.loading "Starting OpenAPI server…"} ;;
        esac
      fi
      exec ${pythonEnv}/bin/python -m ncc_assistant "$@"
    fi

    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.messages.loading "Running command…"}
    fi
    set +e
    ${pythonEnv}/bin/python -m ncc_assistant "$@"
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
      ${ui.messages.success "Done"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc ai --help"}
      fi
    else
      ${ui.messages.error "Command failed (exit $rc)"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc ai --help"}
      fi
    fi
    exit "$rc"
  '';

  nccAssistantMcp = pkgs.writeShellScriptBin "ncc-assistant-mcp" ''
    set -euo pipefail
    ${envExports}
    exec ${pythonEnv}/bin/python -m ncc_assistant mcp
  '';

  nccAssistantTray = pkgs.writeShellScriptBin "ncc-assistant-tray" ''
    set -euo pipefail
    ${envExports}
    exec ${pythonEnv}/bin/python -m ncc_assistant tray
  '';

  nccAssistantCompanion = pkgs.writeShellScriptBin "ncc-assistant-companion" ''
    set -euo pipefail
    ${envExports}
    exec ${pythonEnv}/bin/python -m ncc_assistant companion
  '';

  # Timed domain sinkhole (nft). Needs root (pkexec/sudo). Domains only — not /shorts/ paths.
  nccFocusNetblock = pkgs.writeShellScriptBin "ncc-focus-netblock" ''
    set -euo pipefail
    TABLE=inet
    TNAME=ncc_focus_block
    SET=blocked4
    SET6=blocked6

    usage() {
      echo "Usage: ncc-focus-netblock apply --minutes N --domain d1 [--domain d2 ...]" >&2
      echo "       ncc-focus-netblock clear" >&2
      echo "       ncc-focus-netblock status" >&2
      echo "       ncc-focus-netblock auth-check   # opt-in smoke (Polkit YES if active)" >&2
      exit 2
    }

    need_root() {
      if [ "$(id -u)" -ne 0 ]; then
        if command -v pkexec >/dev/null 2>&1; then
          exec pkexec "$0" "$@"
        fi
        echo "ncc-focus-netblock: need root (or pkexec)" >&2
        exit 1
      fi
    }

    clear_table() {
      ${pkgs.nftables}/bin/nft delete table "$TABLE" "$TNAME" 2>/dev/null || true
    }

    cmd="''${1:-}"
    case "$cmd" in
      auth-check)
        shift || true
        # need_root re-execs: pkexec "$0" <args> — pass only subcommand+args (never "$0")
        need_root auth-check "$@"
        echo "auth-ok"
        ;;
      clear)
        shift || true
        need_root clear "$@"
        clear_table
        echo "cleared"
        ;;
      status)
        ${pkgs.nftables}/bin/nft list table "$TABLE" "$TNAME" 2>/dev/null || echo "inactive"
        ;;
      apply)
        shift || true
        minutes=10
        domains=()
        while [ $# -gt 0 ]; do
          case "$1" in
            --minutes) minutes="''${2:-10}"; shift 2 ;;
            --domain) domains+=("''${2:-}"); shift 2 ;;
            *) usage ;;
          esac
        done
        if [ "''${#domains[@]}" -eq 0 ]; then
          echo "ncc-focus-netblock: no --domain given" >&2
          exit 2
        fi
        need_root apply --minutes "$minutes" $(printf -- '--domain %s ' "''${domains[@]}")
        clear_table
        ${pkgs.nftables}/bin/nft add table "$TABLE" "$TNAME"
        ${pkgs.nftables}/bin/nft add set "$TABLE" "$TNAME" "$SET" '{ type ipv4_addr; flags interval; }'
        ${pkgs.nftables}/bin/nft add set "$TABLE" "$TNAME" "$SET6" '{ type ipv6_addr; flags interval; }'
        ${pkgs.nftables}/bin/nft add chain "$TABLE" "$TNAME" output '{ type filter hook output priority 0; policy accept; }'
        ${pkgs.nftables}/bin/nft add rule "$TABLE" "$TNAME" output ip daddr @"$SET" drop
        ${pkgs.nftables}/bin/nft add rule "$TABLE" "$TNAME" output ip6 daddr @"$SET6" drop

        add_ip() {
          local ip="''${1:-}"
          [ -z "$ip" ] && return 0
          case "$ip" in
            *:*)
              ${pkgs.nftables}/bin/nft add element "$TABLE" "$TNAME" "$SET6" "{ $ip }" 2>/dev/null || true
              ;;
            *)
              ${pkgs.nftables}/bin/nft add element "$TABLE" "$TNAME" "$SET" "{ $ip }" 2>/dev/null || true
              ;;
          esac
          # Kill established streams (Shorts CDN keeps playing otherwise).
          ${pkgs.conntrack-tools}/bin/conntrack -D -d "$ip" >/dev/null 2>&1 || true
          ${pkgs.conntrack-tools}/bin/conntrack -D -q "$ip" >/dev/null 2>&1 || true
        }

        ip_count=0
        for d in "''${domains[@]}"; do
          d="''${d,,}"
          d="''${d#http://}"; d="''${d#https://}"; d="''${d%%/*}"
          [ -z "$d" ] && continue
          while read -r ip; do
            [ -z "$ip" ] && continue
            add_ip "$ip"
            ip_count=$((ip_count + 1))
          done < <(${pkgs.getent}/bin/getent ahosts "$d" 2>/dev/null | awk '{print $1}' | sort -u)
        done

        # Harvest live browser peers (catches rr*.googlevideo.com CDN IPs in use).
        while read -r ip; do
          [ -z "$ip" ] && continue
          add_ip "$ip"
          ip_count=$((ip_count + 1))
        done < <(
          ${pkgs.iproute2}/bin/ss -H -tnp state established 2>/dev/null \
            | ${pkgs.gawk}/bin/awk '
              BEGIN { IGNORECASE=1 }
              /firefox|chrome|chromium|brave|librewolf|navigator/ {
                peer = $5
                if (peer ~ /^\[/) {
                  gsub(/^\[/, "", peer)
                  sub(/\]:[0-9]+$/, "", peer)
                } else {
                  sub(/:[0-9]+$/, "", peer)
                }
                if (peer != "" && peer != "127.0.0.1" && peer != "::1") print peer
              }' | sort -u
        )

        if [ "$ip_count" -eq 0 ]; then
          echo "ncc-focus-netblock: resolved 0 IPs — block empty (DNS/getent failed)" >&2
          clear_table
          exit 3
        fi

        # Auto-clear after N minutes (best-effort)
        ${pkgs.systemd}/bin/systemd-run --quiet --on-active="''${minutes}m" --unit="ncc-focus-netblock-expire" \
          "$0" clear >/dev/null 2>&1 || true
        echo "applied minutes=$minutes ips≈$ip_count domains=''${domains[*]}"
        ;;
      *) usage ;;
    esac
  '';

  # Polkit action for ncc-focus-netblock. Rule in focus-block.nix returns YES for
  # active sessions so Grant/apply never re-prompt mid-doomscroll (auth-check is
  # opt-in smoke + preference gate only).
  nccFocusNetblockPolkitPolicy = pkgs.writeText "org.nixos.ncc.focus-netblock.policy" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC
     "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
    <policyconfig>
      <vendor>NixOS Control Center</vendor>
      <action id="org.nixos.ncc.focus-netblock">
        <description>NCC: timed doomscroll domain sinkhole (nft)</description>
        <message>Authentication is required to apply or clear the NCC focus net-block</message>
        <defaults>
          <allow_any>no</allow_any>
          <allow_inactive>no</allow_inactive>
          <allow_active>auth_admin</allow_active>
        </defaults>
        <annotate key="org.freedesktop.policykit.exec.path">${nccFocusNetblock}/bin/ncc-focus-netblock</annotate>
        <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
      </action>
    </policyconfig>
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "ncc-assistant";
    desktopName = "NCC AI";
    comment = "NixOS Control Center AI assistant";
    exec = "${nccAssistant}/bin/ncc-assistant gui";
    icon = "help-about";
    categories = [ "System" "Utility" ];
    terminal = false;
    actions = {
      PauseAgent = {
        name = "Pause agent";
        exec = "${nccAssistant}/bin/ncc-assistant presence pause";
      };
      ResumeAgent = {
        name = "Resume agent";
        exec = "${nccAssistant}/bin/ncc-assistant presence resume";
      };
      Approvals = {
        name = "List pending approvals";
        exec = "${nccAssistant}/bin/ncc-assistant approve list";
      };
      Tray = {
        name = "Start tray";
        exec = "${nccAssistantTray}/bin/ncc-assistant-tray";
      };
      Companion = {
        name = "Start companion";
        exec = "${nccAssistantCompanion}/bin/ncc-assistant-companion";
      };
    };
  };
in
{
  inherit appRoot configHelper nccAssistant nccAssistantMcp nccAssistantTray nccAssistantCompanion nccFocusNetblock nccFocusNetblockPolkitPolicy pythonEnv desktopItem envExports envFile;
  packages = [ nccAssistant nccAssistantMcp nccAssistantTray nccAssistantCompanion nccFocusNetblock configHelper desktopItem ];
}
