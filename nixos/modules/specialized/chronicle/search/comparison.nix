# Session Comparison System
# Side-by-side session comparison, diff highlighting, and regression detection
{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.modules.specialized.chronicle;
  
  # Compare two sessions
  compareCommand = pkgs.writeShellScriptBin "chronicle-compare" ''
    #!/usr/bin/env bash
    # Compare two recording sessions
    
    set -euo pipefail
    
    SESSION_A="$1"
    SESSION_B="$2"
    OUTPUT_FORMAT="''${3:-html}"  # html, json, or text
    
    SESSION_A_DIR="${cfg.dataDir}/sessions/$SESSION_A"
    SESSION_B_DIR="${cfg.dataDir}/sessions/$SESSION_B"
    OUTPUT_DIR="${cfg.dataDir}/comparisons/$SESSION_A-vs-$SESSION_B"
    
    if [ ! -d "$SESSION_A_DIR" ]; then
      echo "Error: Session A not found: $SESSION_A"
      exit 1
    fi
    
    if [ ! -d "$SESSION_B_DIR" ]; then
      echo "Error: Session B not found: $SESSION_B"
      exit 1
    fi
    
    mkdir -p "$OUTPUT_DIR"
    
    # Extract metadata
    META_A="$SESSION_A_DIR/metadata.json"
    META_B="$SESSION_B_DIR/metadata.json"
    
    TITLE_A=$(${pkgs.jq}/bin/jq -r '.title // "Untitled"' "$META_A")
    TITLE_B=$(${pkgs.jq}/bin/jq -r '.title // "Untitled"' "$META_B")
    
    STEPS_A=$(${pkgs.jq}/bin/jq '.steps | length' "$META_A")
    STEPS_B=$(${pkgs.jq}/bin/jq '.steps | length' "$META_B")
    
    DURATION_A=$(${pkgs.jq}/bin/jq -r '.duration // 0' "$META_A")
    DURATION_B=$(${pkgs.jq}/bin/jq -r '.duration // 0' "$META_B")
    
    # Create comparison JSON
    ${pkgs.jq}/bin/jq -n \
      --arg session_a "$SESSION_A" \
      --arg session_b "$SESSION_B" \
      --arg title_a "$TITLE_A" \
      --arg title_b "$TITLE_B" \
      --argjson steps_a "$STEPS_A" \
      --argjson steps_b "$STEPS_B" \
      --argjson duration_a "$DURATION_A" \
      --argjson duration_b "$DURATION_B" \
      '{
        session_a: $session_a,
        session_b: $session_b,
        comparison: {
          title_a: $title_a,
          title_b: $title_b,
          steps: {
            a: $steps_a,
            b: $steps_b,
            diff: ($steps_b - $steps_a)
          },
          duration: {
            a: $duration_a,
            b: $duration_b,
            diff: ($duration_b - $duration_a)
          }
        },
        timestamp: now
      }' > "$OUTPUT_DIR/comparison.json"
    
    # Generate output based on format
    case "$OUTPUT_FORMAT" in
      json)
        cat "$OUTPUT_DIR/comparison.json"
        ;;
        
      text)
        echo "=== Session Comparison ==="
        echo ""
        echo "Session A: $SESSION_A - $TITLE_A"
        echo "  Steps: $STEPS_A"
        echo "  Duration: $DURATION_A seconds"
        echo ""
        echo "Session B: $SESSION_B - $TITLE_B"
        echo "  Steps: $STEPS_B"
        echo "  Duration: $DURATION_B seconds"
        echo ""
        echo "Differences:"
        echo "  Steps: $(( STEPS_B - STEPS_A )) ($([ $STEPS_B -gt $STEPS_A ] && echo "+" || echo "")$(( STEPS_B - STEPS_A )))"
        echo "  Duration: $(( DURATION_B - DURATION_A ))s ($([ $DURATION_B -gt $DURATION_A ] && echo "+" || echo "")$(( DURATION_B - DURATION_A ))s)"
        echo ""
        echo "Comparison saved to: $OUTPUT_DIR"
        ;;
        
      *)
        # Generate HTML comparison directly in Bash
        cat > "$OUTPUT_DIR/comparison.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Session Comparison</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f5f5f5;
      padding: 20px;
    }
    .container { max-width: 1400px; margin: 0 auto; }
    h1 { color: #333; margin-bottom: 30px; text-align: center; }
    .comparison-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 20px;
      margin-bottom: 30px;
    }
    .session-card {
      background: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .session-card h2 {
      color: #2563eb;
      margin-bottom: 15px;
      font-size: 1.5em;
    }
    .session-card.session-a h2 { color: #dc2626; }
    .session-card.session-b h2 { color: #16a34a; }
    .metric {
      display: flex;
      justify-content: space-between;
      padding: 10px 0;
      border-bottom: 1px solid #e5e7eb;
    }
    .metric:last-child { border-bottom: none; }
    .metric-label { font-weight: 600; color: #6b7280; }
    .metric-value { color: #111827; font-weight: 500; }
    .diff-section {
      background: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .diff-section h2 { color: #333; margin-bottom: 15px; }
    .diff-item {
      padding: 12px;
      margin: 8px 0;
      border-radius: 4px;
      background: #f9fafb;
    }
    .diff-item.positive { background: #dcfce7; border-left: 4px solid #16a34a; }
    .diff-item.negative { background: #fee2e2; border-left: 4px solid #dc2626; }
    .diff-item.neutral { background: #f3f4f6; border-left: 4px solid #6b7280; }
    .badge {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 12px;
      font-size: 0.875em;
      font-weight: 600;
    }
    .badge.increase { background: #fee2e2; color: #dc2626; }
    .badge.decrease { background: #dcfce7; color: #16a34a; }
    .badge.equal { background: #f3f4f6; color: #6b7280; }
  </style>
</head>
<body>
  <div class="container">
    <h1>📊 Session Comparison Report</h1>
    
    <div class="comparison-grid">
      <div class="session-card session-a">
        <h2>Session A: $SESSION_A</h2>
        <div class="metric">
          <span class="metric-label">Title:</span>
          <span class="metric-value">$TITLE_A</span>
        </div>
        <div class="metric">
          <span class="metric-label">Steps:</span>
          <span class="metric-value">$STEPS_A</span>
        </div>
        <div class="metric">
          <span class="metric-label">Duration:</span>
          <span class="metric-value">''${DURATION_A}s</span>
        </div>
      </div>
      
      <div class="session-card session-b">
        <h2>Session B: $SESSION_B</h2>
        <div class="metric">
          <span class="metric-label">Title:</span>
          <span class="metric-value">$TITLE_B</span>
        </div>
        <div class="metric">
          <span class="metric-label">Steps:</span>
          <span class="metric-value">$STEPS_B</span>
        </div>
        <div class="metric">
          <span class="metric-label">Duration:</span>
          <span class="metric-value">''${DURATION_B}s</span>
        </div>
      </div>
    </div>
    
    <div class="diff-section">
      <h2>Differences Analysis</h2>
HTMLEOF

        # Calculate differences
        STEP_DIFF=$((STEPS_B - STEPS_A))
        DURATION_DIFF=$((DURATION_B - DURATION_A))
        
        # Steps difference
        if [ "$STEP_DIFF" -gt 0 ]; then
          echo "      <div class='diff-item negative'>" >> "$OUTPUT_DIR/comparison.html"
          echo "        <strong>Steps:</strong> Increased by $STEP_DIFF steps (+$((STEP_DIFF * 100 / STEPS_A))%) <span class='badge increase'>↑ MORE STEPS</span>" >> "$OUTPUT_DIR/comparison.html"
        elif [ "$STEP_DIFF" -lt 0 ]; then
          echo "      <div class='diff-item positive'>" >> "$OUTPUT_DIR/comparison.html"
          echo "        <strong>Steps:</strong> Decreased by $((-STEP_DIFF)) steps ($((STEP_DIFF * 100 / STEPS_A))%) <span class='badge decrease'>↓ FEWER STEPS</span>" >> "$OUTPUT_DIR/comparison.html"
        else
          echo "      <div class='diff-item neutral'>" >> "$OUTPUT_DIR/comparison.html"
          echo "        <strong>Steps:</strong> No change <span class='badge equal'>= EQUAL</span>" >> "$OUTPUT_DIR/comparison.html"
        fi
        echo "      </div>" >> "$OUTPUT_DIR/comparison.html"
        
        # Duration difference
        if [ "$DURATION_DIFF" -gt 0 ]; then
          echo "      <div class='diff-item negative'>" >> "$OUTPUT_DIR/comparison.html"
          echo "        <strong>Duration:</strong> Increased by ''${DURATION_DIFF}s (+$((DURATION_DIFF * 100 / DURATION_A))%) <span class='badge increase'>↑ SLOWER</span>" >> "$OUTPUT_DIR/comparison.html"
        elif [ "$DURATION_DIFF" -lt 0 ]; then
          echo "      <div class='diff-item positive'>" >> "$OUTPUT_DIR/comparison.html"
          echo "        <strong>Duration:</strong> Decreased by $((-DURATION_DIFF))s ($((DURATION_DIFF * 100 / DURATION_A))%) <span class='badge decrease'>↓ FASTER</span>" >> "$OUTPUT_DIR/comparison.html"
        else
          echo "      <div class='diff-item neutral'>" >> "$OUTPUT_DIR/comparison.html"
          echo "        <strong>Duration:</strong> No change <span class='badge equal'>= EQUAL</span>" >> "$OUTPUT_DIR/comparison.html"
        fi
        echo "      </div>" >> "$OUTPUT_DIR/comparison.html"
        
        cat >> "$OUTPUT_DIR/comparison.html" <<'HTMLEOF'
    </div>
    
    <div style="margin-top: 20px; text-align: center; color: #6b7280; font-size: 0.875em;">
      Generated by NixOS Step Recorder v2.0.0 - Session Comparison Tool
    </div>
  </div>
</body>
</html>
HTMLEOF
        
        echo "Comparison generated: $OUTPUT_DIR/comparison.html"
        
        # Auto-open if enabled
        if ${pkgs.coreutils}/bin/test "${cfg.autoOpen}" = "true"; then
          ${pkgs.xdg-utils}/bin/xdg-open "$OUTPUT_DIR/comparison.html" &
        fi
        ;;
    esac
  '';
  
  # Detect regressions between sessions
  regressionDetection = pkgs.writeShellScriptBin "chronicle-detect-regression" ''
    #!/usr/bin/env bash
    # Detect regressions between two sessions
    
    set -euo pipefail
    
    SESSION_A="$1"  # Baseline session
    SESSION_B="$2"  # Test session
    
    SESSION_A_DIR="${cfg.dataDir}/sessions/$SESSION_A"
    SESSION_B_DIR="${cfg.dataDir}/sessions/$SESSION_B"
    
    if [ ! -d "$SESSION_A_DIR" ] || [ ! -d "$SESSION_B_DIR" ]; then
      echo "Error: One or both sessions not found"
      exit 1
    fi
    
    META_A="$SESSION_A_DIR/metadata.json"
    META_B="$SESSION_B_DIR/metadata.json"
    
    # Extract metrics for comparison
    STEPS_A=$(${pkgs.jq}/bin/jq '.steps | length' "$META_A")
    STEPS_B=$(${pkgs.jq}/bin/jq '.steps | length' "$META_B")
    
    DURATION_A=$(${pkgs.jq}/bin/jq -r '.duration // 0' "$META_A")
    DURATION_B=$(${pkgs.jq}/bin/jq -r '.duration // 0' "$META_B")
    
    ERRORS_A=$(${pkgs.jq}/bin/jq '[.steps[] | select(.type == "error")] | length' "$META_A" 2>/dev/null || echo 0)
    ERRORS_B=$(${pkgs.jq}/bin/jq '[.steps[] | select(.type == "error")] | length' "$META_B" 2>/dev/null || echo 0)
    
    # Regression detection logic
    REGRESSIONS=0
    REGRESSION_DETAILS=""
    
    # Check if more steps are required (potential regression)
    if [ "$STEPS_B" -gt "$((STEPS_A + STEPS_A / 10))" ]; then
      REGRESSIONS=$((REGRESSIONS + 1))
      REGRESSION_DETAILS="$REGRESSION_DETAILS\n- Increased step count: $STEPS_A → $STEPS_B (+$(( (STEPS_B - STEPS_A) * 100 / STEPS_A ))%)"
    fi
    
    # Check if duration increased significantly
    if [ "$DURATION_B" -gt "$((DURATION_A + DURATION_A / 5))" ]; then
      REGRESSIONS=$((REGRESSIONS + 1))
      REGRESSION_DETAILS="$REGRESSION_DETAILS\n- Increased duration: ''${DURATION_A}s → ''${DURATION_B}s (+$(( (DURATION_B - DURATION_A) * 100 / DURATION_A ))%)"
    fi
    
    # Check if more errors occurred
    if [ "$ERRORS_B" -gt "$ERRORS_A" ]; then
      REGRESSIONS=$((REGRESSIONS + 1))
      REGRESSION_DETAILS="$REGRESSION_DETAILS\n- Increased errors: $ERRORS_A → $ERRORS_B"
    fi
    
    # Output results
    echo "=== Regression Detection ==="
    echo "Baseline: $SESSION_A"
    echo "Test: $SESSION_B"
    echo ""
    
    if [ "$REGRESSIONS" -eq 0 ]; then
      echo "✓ No regressions detected"
      exit 0
    else
      echo "⚠ $REGRESSIONS potential regression(s) detected:"
      echo -e "$REGRESSION_DETAILS"
      exit 1
    fi
  '';
  
  # Diff two sessions step-by-step
  diffCommand = pkgs.writeShellScriptBin "chronicle-diff" ''
    #!/usr/bin/env bash
    # Show step-by-step differences between sessions
    
    set -euo pipefail
    
    SESSION_A="$1"
    SESSION_B="$2"
    
    SESSION_A_DIR="${cfg.dataDir}/sessions/$SESSION_A"
    SESSION_B_DIR="${cfg.dataDir}/sessions/$SESSION_B"
    
    if [ ! -d "$SESSION_A_DIR" ] || [ ! -d "$SESSION_B_DIR" ]; then
      echo "Error: One or both sessions not found"
      exit 1
    fi
    
    # Extract step titles
    ${pkgs.jq}/bin/jq -r '.steps[] | .title // "Untitled Step"' "$SESSION_A_DIR/metadata.json" > /tmp/session_a_steps.txt
    ${pkgs.jq}/bin/jq -r '.steps[] | .title // "Untitled Step"' "$SESSION_B_DIR/metadata.json" > /tmp/session_b_steps.txt
    
    # Show diff
    echo "=== Step Differences ==="
    ${pkgs.diffutils}/bin/diff -u /tmp/session_a_steps.txt /tmp/session_b_steps.txt || true
    
    # Cleanup
    rm -f /tmp/session_a_steps.txt /tmp/session_b_steps.txt
  '';
  
  # Batch comparison for multiple sessions
  batchCompare = pkgs.writeShellScriptBin "chronicle-batch-compare" ''
    #!/usr/bin/env bash
    # Compare multiple sessions against a baseline
    
    set -euo pipefail
    
    BASELINE="$1"
    shift
    TEST_SESSIONS=("$@")
    
    REPORT_DIR="${cfg.dataDir}/batch-comparisons/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$REPORT_DIR"
    
    echo "=== Batch Comparison Report ===" > "$REPORT_DIR/report.txt"
    echo "Baseline: $BASELINE" >> "$REPORT_DIR/report.txt"
    echo "Test Sessions: ''${TEST_SESSIONS[@]}" >> "$REPORT_DIR/report.txt"
    echo "" >> "$REPORT_DIR/report.txt"
    
    for session in "''${TEST_SESSIONS[@]}"; do
      echo "Comparing $BASELINE vs $session..." | tee -a "$REPORT_DIR/report.txt"
      
      # Run regression detection
      if ${regressionDetection}/bin/chronicle-detect-regression "$BASELINE" "$session" >> "$REPORT_DIR/report.txt" 2>&1; then
        echo "  ✓ No regressions" | tee -a "$REPORT_DIR/report.txt"
      else
        echo "  ⚠ Regressions detected" | tee -a "$REPORT_DIR/report.txt"
      fi
      
      echo "" >> "$REPORT_DIR/report.txt"
    done
    
    echo "Batch comparison report saved to: $REPORT_DIR/report.txt"
  '';
  
in
{
  # Export comparison utilities
  environment.systemPackages = lib.mkIf cfg.enable [
    compareCommand
    regressionDetection
    diffCommand
    batchCompare
  ];
}
