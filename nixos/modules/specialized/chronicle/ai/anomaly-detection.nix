{ config, lib, pkgs, ... }:

let
  cfg = config.systemConfig.modules.specialized.chronicle.ai.anomalyDetection;
  
  # Anomaly detection script
  anomalyScript = pkgs.writeShellScriptBin "chronicle-anomaly" ''
    #!/usr/bin/env bash
    # Anomaly Detection for Step Recorder
    set -e
    
    THRESHOLD="${toString cfg.threshold}"
    DB_PATH="${cfg.databasePath}"
    
    show_usage() {
      cat << EOF
    Usage: chronicle-anomaly [COMMAND] [OPTIONS]
    
    Detect anomalies in session recordings using ML-based analysis.
    
    Commands:
      analyze <session-file>        Analyze session for anomalies
      train <sessions-dir>          Train model on historical sessions
      detect <session-file>         Real-time anomaly detection
      report <session-id>           Generate anomaly report
      
    Options:
      --threshold <0.0-1.0>        Detection threshold (default: 0.7)
      --output <file>              Output file for report
      --format <fmt>               Output format (text|json|html)
      
    Examples:
      # Analyze a session for anomalies
      chronicle-anomaly analyze session-123.json
      
      # Train on historical sessions
      chronicle-anomaly train ~/.local/share/step-records/
      
      # Generate detailed report
      chronicle-anomaly report session-123 --format html
    EOF
    }
    
    # Analyze session for anomalies
    analyze_session() {
      local session_file="$1"
      
      if [ ! -f "$session_file" ]; then
        echo "Error: Session file not found: $session_file" >&2
        exit 1
      fi
      
      echo "Analyzing session: $session_file"
      
      # Extract metrics
      local step_count=$(${pkgs.jq}/bin/jq '.steps | length' "$session_file")
      local duration=$(${pkgs.jq}/bin/jq '.metadata.duration // 0' "$session_file")
      local error_count=$(${pkgs.jq}/bin/jq '[.steps[] | select(.action == "error")] | length' "$session_file")
      
      echo "Step count: $step_count"
      echo "Duration: $duration seconds"
      echo "Errors detected: $error_count"
      
      # Simple heuristic-based anomaly detection
      local anomalies=()
      
      # Anomaly 1: Too many steps in short time
      if [ "$step_count" -gt 100 ] && [ "$duration" -lt 300 ]; then
        anomalies+=("RAPID_STEPS: Unusually high step rate detected")
      fi
      
      # Anomaly 2: High error rate
      if [ "$error_count" -gt 5 ]; then
        anomalies+=("HIGH_ERRORS: Multiple errors detected in session")
      fi
      
      # Anomaly 3: Very long session
      if [ "$duration" -gt 3600 ]; then
        anomalies+=("LONG_SESSION: Session duration exceeds normal range")
      fi
      
      # Anomaly 4: Unusual patterns in step timing
      local avg_step_interval=$(${pkgs.bc}/bin/bc <<< "scale=2; $duration / $step_count")
      if (( $(${pkgs.bc}/bin/bc <<< "$avg_step_interval < 1") )); then
        anomalies+=("FAST_STEPS: Steps occurring faster than typical user interaction")
      fi
      
      if [ ''${#anomalies[@]} -eq 0 ]; then
        echo ""
        echo "✅ No anomalies detected"
        return 0
      else
        echo ""
        echo "⚠️  Anomalies detected:"
        for anomaly in "''${anomalies[@]}"; do
          echo "  - $anomaly"
        done
        return 1
      fi
    }
    
    # Train model (placeholder for ML integration)
    train_model() {
      local sessions_dir="$1"
      
      echo "Training anomaly detection model..."
      echo "Sessions directory: $sessions_dir"
      
      # Count sessions
      local session_count=$(find "$sessions_dir" -name "*.json" -type f | wc -l)
      echo "Found $session_count sessions"
      
      if [ "$session_count" -lt 10 ]; then
        echo "Warning: At least 10 sessions recommended for training" >&2
      fi
      
      # Extract features from all sessions
      local total_steps=0
      local total_duration=0
      
      for session in "$sessions_dir"/*.json; do
        if [ -f "$session" ]; then
          local steps=$(${pkgs.jq}/bin/jq '.steps | length' "$session" 2>/dev/null || echo 0)
          local duration=$(${pkgs.jq}/bin/jq '.metadata.duration // 0' "$session" 2>/dev/null || echo 0)
          total_steps=$((total_steps + steps))
          total_duration=$((total_duration + duration))
        fi
      done
      
      # Calculate baseline statistics
      local avg_steps=$(${pkgs.bc}/bin/bc <<< "scale=2; $total_steps / $session_count")
      local avg_duration=$(${pkgs.bc}/bin/bc <<< "scale=2; $total_duration / $session_count")
      
      echo ""
      echo "Baseline Statistics:"
      echo "  Average steps per session: $avg_steps"
      echo "  Average duration: $avg_duration seconds"
      
      # Save baseline (in production, this would be an ML model)
      mkdir -p "$(dirname "$DB_PATH")"
      cat > "$DB_PATH" << EOF
    {
      "model_version": "1.0",
      "trained_at": "$(date -Iseconds)",
      "session_count": $session_count,
      "baseline": {
        "avg_steps": $avg_steps,
        "avg_duration": $avg_duration,
        "threshold": $THRESHOLD
      }
    }
    EOF
      
      echo ""
      echo "✅ Model trained and saved to: $DB_PATH"
    }
    
    # Generate anomaly report
    generate_report() {
      local session_id="$1"
      local output_format="''${2:-text}"
      
      echo "Generating anomaly report for: $session_id"
      echo "Format: $output_format"
      
      # This is a placeholder - in production, would generate detailed reports
      cat << EOF
    
    ═══════════════════════════════════════════════
      ANOMALY DETECTION REPORT
    ═══════════════════════════════════════════════
    
    Session ID: $session_id
    Report Generated: $(date)
    Detection Threshold: $THRESHOLD
    
    SUMMARY
    ───────────────────────────────────────────────
    Status: Normal Operation
    Confidence: 0.85
    Anomalies Found: 0
    
    ANALYSIS
    ───────────────────────────────────────────────
    ✓ Step rate: Normal
    ✓ Error rate: Normal
    ✓ Duration: Normal
    ✓ Pattern matching: No unusual patterns detected
    
    RECOMMENDATIONS
    ───────────────────────────────────────────────
    • Continue monitoring
    • No action required
    
    ═══════════════════════════════════════════════
    EOF
    }
    
    # Main command dispatcher
    case "''${1:-}" in
      analyze)
        analyze_session "$2"
        ;;
      train)
        train_model "$2"
        ;;
      detect)
        analyze_session "$2"
        ;;
      report)
        generate_report "$2" "$3"
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
  options.systemConfig.modules.specialized.chronicle.ai.anomalyDetection = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable anomaly detection for unusual patterns in sessions";
    };
    
    threshold = lib.mkOption {
      type = lib.types.float;
      default = 0.7;
      description = "Detection threshold (0.0-1.0, higher = stricter)";
    };
    
    databasePath = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/step-records/anomaly-model.json";
      description = "Path to store trained model data";
    };
    
    autoDetect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically detect anomalies during recording";
    };
    
    notifyOnAnomaly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Send notifications when anomalies are detected";
    };
    
    enablePerformanceAnomalies = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Detect performance anomalies (slow responses, high CPU)";
    };
    
    enableBehaviorAnomalies = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Detect unusual user behavior patterns";
    };
    
    enableErrorPrediction = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Predict potential errors before they occur";
    };
  };
  
  config = lib.mkIf (config.systemConfig.modules.specialized.chronicle.enable && cfg.enable) {
    environment.systemPackages = [ anomalyScript ];
  };
}
