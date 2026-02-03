{ config, lib, pkgs, ... }:

let
  cfg = config.systemConfig.modules.specialized.chronicle.ai.llm;
  
  # LLM integration script
  llmScript = pkgs.writeShellScriptBin "chronicle-llm" ''
    #!/usr/bin/env bash
    # AI-Powered Step Summarization
    set -e
    
    PROVIDER="${cfg.provider}"
    MODEL="${cfg.model}"
    API_KEY_FILE="${cfg.apiKeyFile}"
    ENDPOINT="${cfg.endpoint}"
    MAX_TOKENS="${toString cfg.maxTokens}"
    TEMPERATURE="${toString cfg.temperature}"
    
    show_usage() {
      cat << EOF
    Usage: chronicle-llm [COMMAND] [OPTIONS]
    
    AI-powered features for Step Recorder using LLM integration.
    
    Commands:
      summarize <session-file>      Generate smart summary of a session
      classify <session-file>       Classify bug severity and component
      extract <session-file>        Extract key actions and intents
      similar <session-file>        Find similar sessions
      suggest <session-file>        Suggest automation opportunities
      
    Options:
      --provider <name>            LLM provider (openai|anthropic|ollama)
      --model <name>               Model name
      --output <file>              Output file for results
      --format <fmt>               Output format (text|json|markdown)
      
    Environment Variables:
      OPENAI_API_KEY               OpenAI API key
      ANTHROPIC_API_KEY            Anthropic API key
      OLLAMA_HOST                  Ollama server URL
      
    Examples:
      # Summarize a session
      chronicle-llm summarize session-123.json
      
      # Classify bug with specific model
      chronicle-llm classify session-123.json --model gpt-4
      
      # Extract actions to JSON
      chronicle-llm extract session-123.json --format json
    EOF
    }
    
    # Load API key if file exists
    load_api_key() {
      if [ -f "$API_KEY_FILE" ]; then
        API_KEY=$(cat "$API_KEY_FILE")
      elif [ "$PROVIDER" = "openai" ] && [ -n "$OPENAI_API_KEY" ]; then
        API_KEY="$OPENAI_API_KEY"
      elif [ "$PROVIDER" = "anthropic" ] && [ -n "$ANTHROPIC_API_KEY" ]; then
        API_KEY="$ANTHROPIC_API_KEY"
      else
        echo "Error: API key not found. Set API_KEY_FILE or environment variable." >&2
        exit 1
      fi
    }
    
    # Call LLM API
    call_llm() {
      local prompt="$1"
      local system_prompt="$2"
      
      case "$PROVIDER" in
        openai)
          ${pkgs.curl}/bin/curl -s "$ENDPOINT" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $API_KEY" \
            -d @- << EOF
    {
      "model": "$MODEL",
      "messages": [
        {"role": "system", "content": "$system_prompt"},
        {"role": "user", "content": "$prompt"}
      ],
      "max_tokens": $MAX_TOKENS,
      "temperature": $TEMPERATURE
    }
    EOF
          ;;
        
        anthropic)
          ${pkgs.curl}/bin/curl -s "$ENDPOINT" \
            -H "Content-Type: application/json" \
            -H "x-api-key: $API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -d @- << EOF
    {
      "model": "$MODEL",
      "system": "$system_prompt",
      "messages": [
        {"role": "user", "content": "$prompt"}
      ],
      "max_tokens": $MAX_TOKENS,
      "temperature": $TEMPERATURE
    }
    EOF
          ;;
        
        ollama)
          ${pkgs.curl}/bin/curl -s "$ENDPOINT" \
            -d @- << EOF
    {
      "model": "$MODEL",
      "prompt": "$system_prompt\n\n$prompt",
      "stream": false,
      "options": {
        "temperature": $TEMPERATURE
      }
    }
    EOF
          ;;
        
        *)
          echo "Error: Unknown provider: $PROVIDER" >&2
          exit 1
          ;;
      esac
    }
    
    # Summarize session
    summarize_session() {
      local session_file="$1"
      
      if [ ! -f "$session_file" ]; then
        echo "Error: Session file not found: $session_file" >&2
        exit 1
      fi
      
      # Extract session data
      local session_data=$(${pkgs.jq}/bin/jq -c '.' "$session_file")
      
      local system_prompt="You are an expert at analyzing software troubleshooting sessions. Your task is to create concise, actionable summaries of problem steps recordings."
      
      local prompt="Analyze this session recording and provide:
    1. A brief summary (2-3 sentences)
    2. Key actions performed by the user
    3. Potential issues or errors detected
    4. Recommendations for resolution
    
    Session data:
    $session_data"
      
      load_api_key
      call_llm "$prompt" "$system_prompt" | ${pkgs.jq}/bin/jq -r '.choices[0].message.content // .content[0].text // .response'
    }
    
    # Classify bug
    classify_bug() {
      local session_file="$1"
      local session_data=$(${pkgs.jq}/bin/jq -c '.' "$session_file")
      
      local system_prompt="You are a bug triage specialist. Classify bugs based on severity and component."
      
      local prompt="Analyze this bug report session and classify it:
    1. Severity: critical|high|medium|low
    2. Component: UI|Backend|Database|Network|Security|Performance
    3. Priority: P0|P1|P2|P3
    4. Similar issues (if any)
    
    Output as JSON.
    
    Session data:
    $session_data"
      
      load_api_key
      call_llm "$prompt" "$system_prompt"
    }
    
    # Extract actions
    extract_actions() {
      local session_file="$1"
      local session_data=$(${pkgs.jq}/bin/jq -c '.steps[]' "$session_file")
      
      local system_prompt="You extract and categorize user actions from step recordings."
      
      local prompt="Extract key user actions and their intents from these steps:
    
    Steps:
    $session_data
    
    Output as JSON array with: action, intent, timestamp, importance."
      
      load_api_key
      call_llm "$prompt" "$system_prompt"
    }
    
    # Main command dispatcher
    case "''${1:-}" in
      summarize)
        summarize_session "$2"
        ;;
      classify)
        classify_bug "$2"
        ;;
      extract)
        extract_actions "$2"
        ;;
      similar|suggest)
        echo "Command not yet implemented: $1" >&2
        exit 1
        ;;
      -h|--help|help)
        show_usage
        ;;
      *)
        show_usage
        exit 1
        ;;
    esac
  '';
in
{
  options.systemConfig.modules.specialized.chronicle.ai.llm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable LLM integration for AI-powered features";
    };
    
    provider = lib.mkOption {
      type = lib.types.enum [ "openai" "anthropic" "ollama" "custom" ];
      default = "ollama";
      description = ''
        LLM provider to use:
        - openai: OpenAI GPT models (requires API key)
        - anthropic: Anthropic Claude models (requires API key)
        - ollama: Local Ollama server (free, private)
        - custom: Custom endpoint
      '';
    };
    
    model = lib.mkOption {
      type = lib.types.str;
      default = "llama2";
      example = "gpt-4";
      description = "Model name to use (provider-specific)";
    };
    
    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:11434/api/generate";
      example = "https://api.openai.com/v1/chat/completions";
      description = "API endpoint URL";
    };
    
    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/openai-api-key";
      description = "Path to API key file (if using cloud provider)";
    };
    
    maxTokens = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Maximum tokens for LLM response";
    };
    
    temperature = lib.mkOption {
      type = lib.types.float;
      default = 0.7;
      description = "Temperature for LLM creativity (0.0-1.0)";
    };
    
    enableSummarization = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable smart step summarization";
    };
    
    enableClassification = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable auto-bug classification";
    };
    
    enableIntentDetection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable user intent detection";
    };
  };
  
  config = lib.mkIf (config.systemConfig.modules.specialized.chronicle.enable && cfg.enable) {
    environment.systemPackages = [ llmScript ];
  };
}
