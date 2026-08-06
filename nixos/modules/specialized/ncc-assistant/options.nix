{ lib, ... }:

{
  options.systemConfig.modules.specialized.ncc-assistant = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Module version";
    };

    _dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "cli-registry" "system-manager" ];
      internal = true;
      description = "Modules this module depends on";
    };

    _conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      internal = true;
      description = "Modules that conflict with this module";
    };

    enable = lib.mkEnableOption "NCC AI Assistant (chat + MCP tools for systemConfig)";

    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:11434/v1";
      example = "https://llm.example.com/v1";
      description = ''
        Base URL for an OpenAI-compatible API (`…/v1`). Host-only URLs get `/v1`
        appended automatically. Unused when `api = "anthropic"`.
      '';
    };

    api = lib.mkOption {
      type = lib.types.enum [ "openai-compatible" "anthropic" ];
      default = "openai-compatible";
      description = ''
        Wire protocol for built-in `ncc ai` chat:
        - openai-compatible: POST {endpoint}/chat/completions (Ollama, llama.cpp,
          OpenAI, OpenWebUI, custom gateways, …)
        - anthropic: Anthropic Messages API (ignores endpoint)

        External MCP clients bring their own LLM; this only affects `ncc ai`.
      '';
    };

    # Legacy alias — prefer `api`. Kept so older systemConfig still evaluates.
    provider = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "openai-compatible"
        "anthropic"
        "ollama"
        "openai"
      ]);
      default = null;
      description = ''
        Deprecated alias of `api`. `ollama` / `openai` both mean openai-compatible.
        Prefer setting `api` instead.
      '';
    };

    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Qwen3.6-35B-A3B";
      description = ''
        Model id sent in chat requests. null = auto: GET {endpoint}/models and
        use the first id the gateway advertises (typical for single-model proxies).
      '';
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/ncc-llm-api-key";
      description = ''
        Optional path to an API key file (sops/agenix). Usually leave null:
        `ncc ai` probes the endpoint, prompts for a key if it gets 401/403, and
        caches it in ~/.config/ncc-assistant/credentials.json (mode 0600).
        Never put the key itself in systemConfig.
      '';
    };

    apiHeaderName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "X-API-KEY";
      description = ''
        Optional HTTP header for the API key. null = auto-detect on first auth
        (tries Authorization Bearer, then X-API-KEY) and remember in the local
        credentials cache. Set explicitly only if auto-detect fails.
      '';
    };

    maxTokens = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = ''
        Optional `max_tokens` in the request. null = omit (gateway/server default).
        Only set this if you want to cap replies client-side.
      '';
    };

    temperature = lib.mkOption {
      type = lib.types.nullOr lib.types.float;
      default = null;
      description = ''
        Optional sampling temperature. null = omit (gateway/server default).
      '';
    };

    allowWrite = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow apply_module_config from the built-in `ncc ai` chat (still requires confirm)";
    };

    mcpAllowWrite = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow write tools when serving MCP to external clients (Cursor/Claude Code)";
    };

    allowRebuild = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow apply_system tool (ncc system build switch). Still requires confirm=CONFIRM";
    };
  };
}
