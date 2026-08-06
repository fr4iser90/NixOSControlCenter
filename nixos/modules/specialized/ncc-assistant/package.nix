# Builds ncc-assistant binaries (GUI chat + MCP) and config facade helper.
{ pkgs, lib, cfg }:

let
  facade = import ../../../core/management/system-manager/lib/config-facade.nix {
    inherit pkgs;
  };

  # Knowledge must live inside the flake root (nixos/). Repo-root ../../../../knowledge
  # escapes to /nix/store/knowledge under pure eval and breaks the build.
  knowledgeSrc = ./knowledge;
  aiKnowledgeSrc = ./AI_KNOWLEDGE.md;

  appRoot = pkgs.runCommand "ncc-assistant-src" { } ''
    mkdir -p $out
    cp -r ${./python/ncc_assistant} $out/ncc_assistant
    cp -r ${./prompts} $out/prompts
    cp -r ${knowledgeSrc} $out/knowledge
    cp ${aiKnowledgeSrc} $out/AI_KNOWLEDGE.md
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
      echo "Usage: ncc-assistant-config read <module_path>" >&2
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
    export PYTHONPATH="${appRoot}''${PYTHONPATH:+:$PYTHONPATH}"
    export PATH="${configHelper}/bin:${pkgs.jq}/bin:${pkgs.nix}/bin:$PATH"
    # Qt/Plasma: use system platform theme when available
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
  '';

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

  desktopItem = pkgs.makeDesktopItem {
    name = "ncc-assistant";
    desktopName = "NCC AI";
    comment = "NixOS Control Center AI assistant";
    exec = "${nccAssistant}/bin/ncc-assistant gui";
    icon = "help-about";
    categories = [ "System" "Utility" ];
    terminal = false;
  };
in
{
  inherit appRoot configHelper nccAssistant nccAssistantMcp pythonEnv desktopItem;
  packages = [ nccAssistant nccAssistantMcp configHelper desktopItem ];
}
