{ lib, pkgs, cfg }:

# Performance Metrics - Track CPU/RAM/Network per step

pkgs.writeShellScriptBin "chronicle-metrics" ''
  #!/usr/bin/env bash
  set -euo pipefail

  usage() {
    cat << EOF
  Performance Metrics for Step Recorder
  
  Usage: chronicle-metrics <command> [options]
  
  Commands:
    collect <session_id>         - Collect metrics for session
    report <session_id>          - Generate metrics report
    chart <session_id>           - Generate Chart.js visualization
    
  Collected Metrics:
    - CPU usage per step
    - Memory (RAM) usage per step
    - Network I/O per step
    - Process list per step
    - System load average
  EOF
  }
  
  collect_metrics() {
    local session_id="$1"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local metrics_file="$output_dir/$session_id/metrics.json"
    
    # CPU usage
    local cpu=$(${pkgs.procps}/bin/top -bn1 | grep "Cpu(s)" | ${pkgs.gawk}/bin/awk '{print 100 - $8}')
    
    # Memory usage
    local mem=$(${pkgs.procps}/bin/free -m | ${pkgs.gawk}/bin/awk 'NR==2{printf "%.2f", $3*100/$2}')
    
    # Network I/O
    local net_rx=$(cat /proc/net/dev | ${pkgs.gawk}/bin/awk '/eth0|wlan0/{rx+=$2} END{print rx}')
    local net_tx=$(cat /proc/net/dev | ${pkgs.gawk}/bin/awk '/eth0|wlan0/{tx+=$10} END{print tx}')
    
    # System load
    local load=$(cat /proc/loadavg | ${pkgs.gawk}/bin/awk '{print $1}')
    
    # Create metrics entry
    ${pkgs.jq}/bin/jq -n \
      --arg ts "$(date -Iseconds)" \
      --arg cpu "$cpu" \
      --arg mem "$mem" \
      --arg net_rx "$net_rx" \
      --arg net_tx "$net_tx" \
      --arg load "$load" \
      '{timestamp: $ts, cpu: $cpu, memory: $mem, network: {rx: $net_rx, tx: $net_tx}, load: $load}' \
      >> "$metrics_file"
  }
  
  generate_report() {
    local session_id="$1"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local metrics_file="$output_dir/$session_id/metrics.json"
    local report_file="$output_dir/$session_id/metrics-report.html"
    
    [ ! -f "$metrics_file" ] && { echo "No metrics found"; exit 1; }
    
    cat > "$report_file" << 'HTML'
<!DOCTYPE html>
<html><head>
<title>Performance Metrics</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
body{font-family:sans-serif;max-width:1200px;margin:20px auto;padding:20px}
.chart{margin:30px 0;height:300px}
</style>
</head><body>
<h1>Performance Metrics Report</h1>
<div class="chart"><canvas id="cpuChart"></canvas></div>
<div class="chart"><canvas id="memChart"></canvas></div>
<script>
const metrics = [METRICS_DATA];
new Chart(document.getElementById('cpuChart'), {
  type: 'line',
  data: {
    labels: metrics.map(m => m.timestamp),
    datasets: [{label: 'CPU %', data: metrics.map(m => m.cpu), borderColor: 'rgb(75, 192, 192)'}]
  }
});
new Chart(document.getElementById('memChart'), {
  type: 'line',
  data: {
    labels: metrics.map(m => m.timestamp),
    datasets: [{label: 'Memory %', data: metrics.map(m => m.memory), borderColor: 'rgb(255, 99, 132)'}]
  }
});
</script>
</body></html>
HTML
    
    # Insert metrics data
    local metrics_json=$(cat "$metrics_file" | ${pkgs.jq}/bin/jq -s '.')
    sed -i "s/\[METRICS_DATA\]/$metrics_json/" "$report_file"
    
    echo "Report generated: $report_file"
    ${pkgs.xdg-utils}/bin/xdg-open "$report_file" 2>/dev/null || true
  }
  
  case "''${1:-help}" in
    collect) collect_metrics "$2" ;;
    report) generate_report "$2" ;;
    help|*) usage ;;
  esac
''
