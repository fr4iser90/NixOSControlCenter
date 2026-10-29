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

  # Staging root holds ONLY importable packages under lib/ncc-assistant, so PYTHONPATH never
  # exposes doc/, lib/*.nix or the module source itself. Catalogs go to $out/data (data, not
  # code — the loaders reach them through NCC_DATA_ROOT, not importlib.resources).
  #
  # Every package names its destination. A path literal is /nix/store/<hash>-<dir>, and
  # `cp -r SRC… DEST/` keeps that basename when DEST exists — the package would land as
  # <hash>-window and nothing could import it.
  appRoot = pkgs.runCommand "ncc-assistant-src" { } ''
    mkdir -p $out/lib/ncc-assistant
    cp -r ${./cli} $out/lib/ncc-assistant/cli
    cp -r ${./companion} $out/lib/ncc-assistant/companion
    cp -r ${./core} $out/lib/ncc-assistant/core
    cp -r ${./harness} $out/lib/ncc-assistant/harness
    cp -r ${./plugins} $out/lib/ncc-assistant/plugins
    cp -r ${./tray} $out/lib/ncc-assistant/tray
    cp -r ${./widgets} $out/lib/ncc-assistant/widgets
    cp -r ${./window} $out/lib/ncc-assistant/window
    cp -r ${guiEngine.src}/ncc_gui $out/lib/ncc-assistant/ncc_gui
    cp -r ${./data} $out/data
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

  # envExports is inlined into every wrapper body, so it runs *after* systemd applied
  # Environment= — a plain assignment would erase a schedule unit's narrowing, while
  # leaving the variable untouched would let an inherited value widen the host. The host
  # value is the ceiling: false stays a hard "0", true lets the unit lower it to "0".
  narrowBoolExport = name: hostValue:
    if hostValue then ''export ${name}="''${${name}:-1}"'' else ''export ${name}="0"'';

  # Not a gate: the host value is a default, never a verdict. A schedule unit that names its
  # own model is the narrowest scope that declared it and must survive this file, so unlike
  # narrowBoolExport an inherited value is allowed to override the host default here.
  respectUnitExport = name: defaultValue: ''export ${name}="''${${name}:-${defaultValue}}"'';

  # confirm is a gate like the bool pair but it narrows in the *opposite* direction: always
  # asks for every tool (narrowest), never asks for nothing (widest). So the unit may only
  # raise how much is asked, and the clamp has to be a rank rather than a boolean — keeping
  # any inherited value would let a unit pick "never" on a host that said "writes".
  # Unset, unknown or wider-than-host values fall back to the host; narrower ones survive.
  narrowConfirmExport = name: hostValue:
    let
      askRank = { always = 2; writes = 1; never = 0; };
      host = if builtins.isString hostValue && askRank ? ${hostValue} then hostValue else "writes";
      askAtLeast = builtins.filter (mode: askRank.${mode} >= askRank.${host}) (builtins.attrNames askRank);
    in ''
      case "''${${name}:-}" in
        ${lib.concatStringsSep "|" askAtLeast}) : ;;
        *) ${name}="${host}";;
      esac
      export ${name}
    '';

  envExports = ''
    export NCC_ASSISTANT_ROOT="${appRoot}"
    export NCC_KNOWLEDGE_ROOT="${appRoot}/knowledge"
    export NCC_DATA_ROOT="${appRoot}/data"
    export NCC_PROMPTS_ROOT="${appRoot}/data/prompts"
    export NCC_ASSISTANT_CONFIG_BIN="${configHelper}/bin/ncc-assistant-config"
    export NCC_ASSISTANT_API="${resolvedApi}"
    export NCC_ASSISTANT_ENDPOINT="${cfg.endpoint or "http://localhost:11434/v1"}"
    ${lib.optionalString ((cfg.model or null) != null) ''
      ${respectUnitExport "NCC_ASSISTANT_MODEL" cfg.model}
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
    # Both naming conventions: GUI reads AGENT_MAX_STEPS, Settings reads the prefixed one.
    export AGENT_MAX_STEPS="${toString (cfg.agent.maxSteps or (-1))}"
    export NCC_ASSISTANT_AGENT_MAX_STEPS="${toString (cfg.agent.maxSteps or (-1))}"
    export NCC_ASSISTANT_CHAT_MAX_ROUNDS="${toString (cfg.agent.chatMaxRounds or (-1))}"
    # Chat context window + compaction, all in tokens. Unset window = probe the gateway.
    ${lib.optionalString ((cfg.agent.contextWindow or null) != null) ''
      export NCC_ASSISTANT_CONTEXT_WINDOW="${toString cfg.agent.contextWindow}"
    ''}
    export NCC_ASSISTANT_COMPACT_THRESHOLD="${toString (cfg.agent.compactThreshold or (-1))}"
    export NCC_ASSISTANT_AUTO_COMPACT="${if (cfg.agent.autoCompact or true) then "1" else "0"}"
    export AGENT_TIMEOUT_SEC="${toString (cfg.agent.timeoutSec or 1800)}"
    # Permission gates: the narrowest scope (schedule unit, --grant) may lower these,
    # never raise them above what the host allows.
    ${narrowBoolExport "AGENT_ALLOW_WRITE" (cfg.agent.allowWrite or false)}
    ${narrowBoolExport "AGENT_ALLOW_REBUILD" (cfg.agent.allowRebuild or false)}
    ${narrowBoolExport "NCC_ASSISTANT_AGENT_ALLOW_WRITE" (cfg.agent.allowWrite or false)}
    ${narrowBoolExport "NCC_ASSISTANT_AGENT_ALLOW_REBUILD" (cfg.agent.allowRebuild or false)}
    ${narrowConfirmExport "AGENT_CONFIRM" (cfg.agent.confirm or "writes")}
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

    export PYTHONPATH="${appRoot}/lib/ncc-assistant''${PYTHONPATH:+:$PYTHONPATH}"
    # wtype: leave-feed tab (about:blank) on Plasma Wayland after net-block
    # gh/git are declared, not inherited. workflows.py and cli/workspace_lifecycle.py call gh, and
    # poll_guard/permissions/workspaces call git; a host whose environment happens to carry git
    # hides that the dependency was never stated, and on one that does not, every GitHub verb died
    # with "gh CLI not on PATH" in a run that otherwise looked correctly configured.
    #
    # uv ships uvx, which three of the four packaged MCP templates (github, git, fetch) name as
    # their command. marketplace.install never asked whether that command existed: it wrote the
    # server entry, reported success, and the spawn failed later in whichever run first reached
    # for the tool. Same process, same PATH as that spawn, so declaring it here is what makes
    # install_template's launchability check mean the same thing to the operator as to the run.
    export PATH="${configHelper}/bin:${nccFocusNetblock}/bin:${pkgs.wtype}/bin:${pkgs.jq}/bin:${pkgs.nix}/bin:${pkgs.gh}/bin:${pkgs.git}/bin:${pkgs.uv}/bin:$PATH"
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
      exec ${pythonEnv}/bin/python -m cli "$@"
    fi

    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.messages.loading "Running command…"}
    fi
    set +e
    ${pythonEnv}/bin/python -m cli "$@"
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
    exec ${pythonEnv}/bin/python -m cli mcp
  '';

  nccAssistantTray = pkgs.writeShellScriptBin "ncc-assistant-tray" ''
    set -euo pipefail
    ${envExports}
    exec ${pythonEnv}/bin/python -m cli tray
  '';

  nccAssistantCompanion = pkgs.writeShellScriptBin "ncc-assistant-companion" ''
    set -euo pipefail
    ${envExports}
    exec ${pythonEnv}/bin/python -m cli companion
  '';

  # Timed domain sinkhole (nft). Needs root (pkexec/sudo). Domains only — not /shorts/ paths.
  nccFocusNetblock = pkgs.writeShellScriptBin "ncc-focus-netblock" ''
    set -euo pipefail
    TABLE=inet
    TNAME=ncc_focus_block
    SET=blocked4
    SET6=blocked6
    # User-readable marker (nft list needs root — status would look inactive otherwise)
    MARKER=/run/ncc-focus-netblock

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
      rm -f "$MARKER" 2>/dev/null || true
    }

    write_marker() {
      local until_ts="''${1:-0}"
      printf 'until=%s\nactive=1\n' "$until_ts" > "$MARKER" 2>/dev/null || true
      chmod 644 "$MARKER" 2>/dev/null || true
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
        if [ -f "$MARKER" ]; then
          until_line="$(grep -E '^until=' "$MARKER" 2>/dev/null || true)"
          until_ts="''${until_line#until=}"
          now_ts="$(${pkgs.coreutils}/bin/date +%s)"
          if [ -n "$until_ts" ] && [ "$until_ts" -gt "$now_ts" ] 2>/dev/null; then
            echo "active ''${until_line}"
            ${pkgs.nftables}/bin/nft list table "$TABLE" "$TNAME" 2>/dev/null || true
            exit 0
          fi
        fi
        if ${pkgs.nftables}/bin/nft list table "$TABLE" "$TNAME" 2>/dev/null; then
          exit 0
        fi
        echo "inactive"
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

        until_ts=$(( $(${pkgs.coreutils}/bin/date +%s) + minutes * 60 ))
        write_marker "$until_ts"

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

  # Python payload the `ai` GUI page needs (cli-registry registerGuiPython). gui-engine
  # stages this directory's children and exports guiEnv — it must never learn that the
  # children are core/window/tray/…, so this is the only place that list exists (doc/layout.md).
  guiPythonRoot = "${appRoot}/lib/ncc-assistant";
  guiEnv = {
    # Catalogs left the package, so the loader root has to be named here; unset would make
    # every catalog read return [] silently instead of failing.
    NCC_DATA_ROOT = "${appRoot}/data";
    NCC_PROMPTS_ROOT = "${appRoot}/data/prompts";
  };
  # Generated tool index is read by path, so a new path means the embedded panel would keep
  # serving the old list — hard-restart the GUI on it (ncc_gui.reload).
  guiFingerprint = [ domainAi.indexFile ];
}
