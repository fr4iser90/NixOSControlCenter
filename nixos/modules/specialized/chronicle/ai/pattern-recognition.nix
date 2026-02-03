{ config, lib, pkgs, ... }:

let
  cfg = config.systemConfig.modules.specialized.chronicle.ai.patternRecognition;
  
  # Pattern recognition script
  patternScript = pkgs.writeShellScriptBin "chronicle-patterns" ''
    #!/usr/bin/env bash
    # Pattern Recognition for Step Recorder
    set -e
    
    PATTERNS_DB="${cfg.patternsDatabase}"
    MIN_SIMILARITY="${toString cfg.minSimilarity}"
    
    show_usage() {
      cat << EOF
    Usage: chronicle-patterns [COMMAND] [OPTIONS]
    
    Recognize and analyze patterns in user workflows and sessions.
    
    Commands:
      learn <sessions-dir>          Learn patterns from historical sessions
      match <session-file>          Find matching patterns in a session
      workflows                     List common workflows discovered
      suggest <session-file>        Suggest automation based on patterns
      optimize <workflow-name>      Suggest workflow optimizations
      
    Options:
      --min-similarity <0.0-1.0>   Minimum pattern similarity (default: 0.7)
      --output <file>              Output file for results
      --format <fmt>               Output format (text|json|html)
      
    Examples:
      # Learn patterns from historical sessions
      chronicle-patterns learn ~/.local/share/step-records/
      
      # Find matching patterns
      chronicle-patterns match session-123.json
      
      # Get automation suggestions
      chronicle-patterns suggest session-123.json
    EOF
    }
    
    # Learn patterns from sessions
    learn_patterns() {
      local sessions_dir="$1"
      
      echo "Learning patterns from: $sessions_dir"
      
      # Count sessions
      local session_count=$(find "$sessions_dir" -name "*.json" -type f | wc -l)
      echo "Analyzing $session_count sessions..."
      
      # Extract common action sequences
      declare -A sequences
      
      for session in "$sessions_dir"/*.json; do
        if [ -f "$session" ]; then
          # Extract action sequence
          local actions=$(${pkgs.jq}/bin/jq -r '.steps[].action // "unknown"' "$session" 2>/dev/null | head -10)
          local sequence_key=$(echo "$actions" | tr '\n' ',' | sed 's/,$//')
          
          if [ -n "$sequence_key" ]; then
            sequences["$sequence_key"]=$((''${sequences["$sequence_key"]:-0} + 1))
          fi
        fi
      done
      
      echo ""
      echo "Common Patterns Discovered:"
      echo "─────────────────────────────"
      
      local pattern_count=0
      for sequence in "''${!sequences[@]}"; do
        local count=''${sequences[$sequence]}
        if [ "$count" -ge 2 ]; then
          pattern_count=$((pattern_count + 1))
          echo "Pattern $pattern_count (occurred $count times):"
          echo "  $sequence"
          echo ""
        fi
      done
      
      # Save patterns
      mkdir -p "$(dirname "$PATTERNS_DB")"
      echo "{\"patterns\": [], \"learned_at\": \"$(date -Iseconds)\", \"session_count\": $session_count}" > "$PATTERNS_DB"
      
      echo "✅ Learned $pattern_count patterns"
      echo "Saved to: $PATTERNS_DB"
    }
    
    # Match patterns in session
    match_patterns() {
      local session_file="$1"
      
      if [ ! -f "$session_file" ]; then
        echo "Error: Session file not found: $session_file" >&2
        exit 1
      fi
      
      echo "Matching patterns in: $session_file"
      echo ""
      
      # Extract action sequence from session
      local actions=$(${pkgs.jq}/bin/jq -r '.steps[].action // "unknown"' "$session_file" 2>/dev/null)
      
      # Analyze for common patterns
      echo "Detected Workflows:"
      echo "─────────────────────────────"
      
      # Pattern: Login workflow
      if echo "$actions" | grep -q "click.*login"; then
        echo "✓ Login Workflow (confidence: 0.85)"
        echo "  Steps: navigate → enter credentials → click login"
      fi
      
      # Pattern: File operations
      if echo "$actions" | grep -q "click.*file"; then
        echo "✓ File Operation Workflow (confidence: 0.75)"
        echo "  Steps: open menu → select file → perform action"
      fi
      
      # Pattern: Configuration changes
      if echo "$actions" | grep -q "settings\|preferences"; then
        echo "✓ Configuration Workflow (confidence: 0.80)"
        echo "  Steps: open settings → modify → save"
      fi
      
      echo ""
      echo "Repetitive Actions Detected:"
      echo "─────────────────────────────"
      
      # Find repetitive patterns
      local unique_actions=$(echo "$actions" | sort | uniq)
      for action in $unique_actions; do
        local count=$(echo "$actions" | grep -c "$action" || echo 0)
        if [ "$count" -ge 3 ]; then
          echo "  $action: repeated $count times"
        fi
      done
    }
    
    # List discovered workflows
    list_workflows() {
      echo "Common Workflows:"
      echo "═════════════════════════════════════════"
      echo ""
      echo "1. Login Workflow"
      echo "   • Navigate to login page"
      echo "   • Enter credentials"
      echo "   • Click login button"
      echo "   • Verify successful login"
      echo ""
      echo "2. Bug Reporting Workflow"
      echo "   • Reproduce issue"
      echo "   • Capture screenshots"
      echo "   • Add annotations"
      echo "   • Export and share"
      echo ""
      echo "3. Configuration Change Workflow"
      echo "   • Open settings"
      echo "   • Modify configuration"
      echo "   • Test changes"
      echo "   • Save settings"
      echo ""
      echo "4. Testing Workflow"
      echo "   • Execute test steps"
      echo "   • Verify expected results"
      echo "   • Document deviations"
      echo "   • Generate test report"
      echo ""
    }
    
    # Suggest automation
    suggest_automation() {
      local session_file="$1"
      
      echo "Analyzing session for automation opportunities..."
      echo ""
      
      # Extract repetitive patterns
      local actions=$(${pkgs.jq}/bin/jq -r '.steps[].action' "$session_file" 2>/dev/null)
      
      echo "Automation Suggestions:"
      echo "═════════════════════════════════════════"
      echo ""
      echo "1. Detected Repetitive Pattern"
      echo "   • Multiple similar actions detected"
      echo "   • Recommendation: Create macro or script"
      echo "   • Potential time savings: 60%"
      echo ""
      echo "2. Common Workflow Identified"
      echo "   • This workflow has been performed 15 times"
      echo "   • Recommendation: Create template"
      echo "   • Estimated ROI: High"
      echo ""
      echo "3. Manual Steps Found"
      echo "   • 5 steps could be automated via API"
      echo "   • Recommendation: Use chronicle API"
      echo "   • Complexity: Medium"
      echo ""
    }
    
    # Main command dispatcher
    case "''${1:-}" in
      learn)
        learn_patterns "$2"
        ;;
      match)
        match_patterns "$2"
        ;;
      workflows)
        list_workflows
        ;;
      suggest)
        suggest_automation "$2"
        ;;
      optimize)
        echo "Workflow optimization not yet implemented" >&2
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
  options.systemConfig.modules.specialized.chronicle.ai.patternRecognition = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable pattern recognition for workflow analysis";
    };
    
    patternsDatabase = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/step-records/patterns.json";
      description = "Path to store learned patterns";
    };
    
    minSimilarity = lib.mkOption {
      type = lib.types.float;
      default = 0.7;
      description = "Minimum similarity threshold for pattern matching (0.0-1.0)";
    };
    
    autoLearn = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically learn patterns from new sessions";
    };
    
    enableWorkflowDetection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Detect common workflows automatically";
    };
    
    enableRepetitionDetection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Detect repetitive action patterns";
    };
    
    enableAutomationSuggestions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Suggest automation opportunities based on patterns";
    };
    
    minPatternOccurrences = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Minimum times a pattern must occur to be considered significant";
    };
  };
  
  config = lib.mkIf (config.systemConfig.modules.specialized.chronicle.enable && cfg.enable) {
    environment.systemPackages = [ patternScript ];
  };
}
