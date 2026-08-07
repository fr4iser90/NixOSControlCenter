# Builds ncc-assistant binaries (GUI chat + MCP + agent + tray) and config facade helper.
{ pkgs, lib, cfg, getModuleApi, getModuleMetadata }:

let
  facade = import "${(getModuleMetadata "system-manager").path}/lib/config-facade.nix" {
    inherit pkgs;
  };

  knowledgeSrc = ./knowledge;
  aiKnowledgeSrc = ./AI_KNOWLEDGE.md;

  guiEngine = (getModuleApi "gui-engine").package pkgs;

  appRoot = pkgs.runCommand "ncc-assistant-src" { } ''
    mkdir -p $out
    cp -r ${./python/ncc_assistant} $out/ncc_assistant
    cp -r ${./prompts} $out/prompts
    cp -r ${knowledgeSrc} $out/knowledge
    cp ${aiKnowledgeSrc} $out/AI_KNOWLEDGE.md
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

    usage() {
      echo "Usage: ncc ai config-helper read <module_path>" >&2
      echo "       ncc-assistant-config write <module_path>   # content on stdin" >&2
      echo "       ncc-assistant-config validate               # Nix fragment on stdin" >&2
      exit 2
    }

    cmd="''${1:-}"
    case "$cmd" in
      read)
        [[ $# -ge 2 ]] || usage
        ncc_read_module_config "$2"
        ;;
      write)
        [[ $# -ge 2 ]] || usage
        content=$(cat)
        ncc_write_module_config "$2" "$content"
        ;;
      validate)
        content=$(cat)
        if ${pkgs.nix}/bin/nix-instantiate --parse -E "$content" >/dev/null 2>&1; then
          echo "valid"
          exit 0
        fi
        if ${pkgs.nix}/bin/nix-instantiate --eval --strict -E "$content" >/dev/null 2>&1; then
          echo "valid"
          exit 0
        fi
        echo "Invalid Nix fragment" >&2
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
    exec ${pythonEnv}/bin/python -m ncc_assistant "$@"
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
