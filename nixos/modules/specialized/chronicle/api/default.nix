{ lib, pkgs, cfg }:

# API Module - REST API for Step Recorder
# Provides HTTP endpoints for remote control and integration

{
  # API Server
  server = import ./server.nix { inherit lib pkgs cfg; };
  
  # API Client (for testing and scripting)
  client = pkgs.writeShellScriptBin "chronicle-api-client" ''
    #!/usr/bin/env bash
    # Simple API client for testing
    
    API_URL="''${CHRONICLE_API_URL:-http://${cfg.api.host}:${toString cfg.api.port}}"
    API_TOKEN="''${CHRONICLE_API_TOKEN:-}"
    
    usage() {
      cat << EOF
    Step Recorder API Client
    
    Usage: chronicle-api-client <command> [args]
    
    Commands:
      auth                      - Get authentication token
      sessions                  - List all sessions
      session <id>              - Get session details
      steps <session_id>        - List steps in a session
      start [title]             - Start recording
      stop                      - Stop recording
      export <session_id> <fmt> - Export session (html/md/json/pdf/zip)
      stats                     - Get statistics
      health                    - Check API health
    
    Environment:
      CHRONICLE_API_URL   - API base URL (default: $API_URL)
      CHRONICLE_API_TOKEN - API authentication token
    
    Examples:
      # Get auth token
      chronicle-api-client auth
      
      # Start recording
      export CHRONICLE_API_TOKEN="your-token"
      chronicle-api-client start "Bug Report"
      
      # List sessions
      chronicle-api-client sessions
    EOF
    }
    
    api_call() {
      local method="$1"
      local endpoint="$2"
      local data="$3"
      
      local auth_header=""
      if [ -n "$API_TOKEN" ]; then
        auth_header="Authorization: Bearer $API_TOKEN"
      fi
      
      if [ -n "$data" ]; then
        ${pkgs.curl}/bin/curl -s -X "$method" \
          "$API_URL$endpoint" \
          -H "Content-Type: application/json" \
          -H "$auth_header" \
          -d "$data"
      else
        ${pkgs.curl}/bin/curl -s -X "$method" \
          "$API_URL$endpoint" \
          -H "$auth_header"
      fi
    }
    
    case "''${1:-help}" in
      auth)
        echo "Getting authentication token..."
        response=$(api_call POST "/auth/token" "")
        echo "$response" | ${pkgs.jq}/bin/jq -r '.access_token'
        ;;
        
      sessions)
        api_call GET "/sessions" "" | ${pkgs.jq}/bin/jq '.'
        ;;
        
      session)
        if [ -z "$2" ]; then
          echo "Error: session ID required"
          exit 1
        fi
        api_call GET "/sessions/$2" "" | ${pkgs.jq}/bin/jq '.'
        ;;
        
      steps)
        if [ -z "$2" ]; then
          echo "Error: session ID required"
          exit 1
        fi
        api_call GET "/sessions/$2/steps" "" | ${pkgs.jq}/bin/jq '.'
        ;;
        
      start)
        local title="''${2:-Recording Session}"
        data=$(${pkgs.jq}/bin/jq -n --arg title "$title" '{action: "start", title: $title}')
        api_call POST "/recording" "$data" | ${pkgs.jq}/bin/jq '.'
        ;;
        
      stop)
        data='{"action": "stop"}'
        api_call POST "/recording" "$data" | ${pkgs.jq}/bin/jq '.'
        ;;
        
      export)
        if [ -z "$2" ] || [ -z "$3" ]; then
          echo "Error: session ID and format required"
          echo "Usage: export <session_id> <format>"
          exit 1
        fi
        data=$(${pkgs.jq}/bin/jq -n --arg sid "$2" --arg fmt "$3" '{session_id: $sid, format: $fmt}')
        api_call POST "/export" "$data" | ${pkgs.jq}/bin/jq '.'
        ;;
        
      stats)
        api_call GET "/stats" "" | ${pkgs.jq}/bin/jq '.'
        ;;
        
      health)
        api_call GET "/health" "" | ${pkgs.jq}/bin/jq '.'
        ;;
        
      help|*)
        usage
        ;;
    esac
  '';
}
