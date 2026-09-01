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

    # Agent tray
    export AGENT_TRAY_ENABLE="${if (cfg.agent.tray.enable or false) then "1" else "0"}"

    # Schedules + host profiles (for UI / rebuild guards)
    export NCC_ASSISTANT_SCHEDULES_JSON='${schedulesJson}'
    export NCC_ASSISTANT_HOST_PROFILES_JSON='${hostProfilesJson}'

    export PYTHONPATH="${appRoot}''${PYTHONPATH:+:$PYTHONPATH}"
    export PATH="${configHelper}/bin:${pkgs.jq}/bin:${pkgs.nix}/bin:$PATH"
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
      ""|gui|chat|cli|mcp|tray|serve-openapi|help|-h|--help) interactive=1 ;;
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
    };
  };
in
{
  inherit appRoot configHelper nccAssistant nccAssistantMcp nccAssistantTray pythonEnv desktopItem envExports envFile;
  packages = [ nccAssistant nccAssistantMcp nccAssistantTray configHelper desktopItem ];
}
