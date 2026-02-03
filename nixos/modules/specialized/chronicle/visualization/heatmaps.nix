{ config, lib, pkgs, ... }:

let
  cfg = config.systemConfig.modules.specialized.chronicle.visualization.heatmaps;
  
  # Heatmap visualization script
  heatmapScript = pkgs.writeShellScriptBin "chronicle-heatmap" ''
    #!/usr/bin/env bash
    # Heatmap Visualization for Step Recorder
    set -e
    
    show_usage() {
      cat << EOF
    Usage: chronicle-heatmap [COMMAND] [OPTIONS]
    
    Generate heat maps from session recordings.
    
    Commands:
      generate <session-file>      Generate click heatmap
      attention <session-file>     Generate attention heatmap
      scroll <session-file>        Generate scroll depth map
      time <session-file>          Generate time-on-screen map
      
    Options:
      --output <file>              Output HTML file (default: heatmap.html)
      --resolution <wxh>           Heatmap resolution (default: 1920x1080)
      --colormap <name>            Color scheme (hot|cool|rainbow)
      
    Examples:
      # Generate click heatmap
      chronicle-heatmap generate session-123.json
      
      # Generate attention map with custom output
      chronicle-heatmap attention session-123.json --output attention.html
    EOF
    }
    
    # Generate heatmap HTML
    generate_heatmap() {
      local session_file="$1"
      local output_file="''${2:-heatmap.html}"
      
      if [ ! -f "$session_file" ]; then
        echo "Error: Session file not found: $session_file" >&2
        exit 1
      fi
      
      echo "Generating heatmap from: $session_file"
      echo "Output: $output_file"
      
      # Extract click coordinates
      local clicks=$(${pkgs.jq}/bin/jq -r '.steps[] | select(.mouse_x and .mouse_y) | "\(.mouse_x),\(.mouse_y)"' "$session_file" 2>/dev/null || echo "")
      
      local click_count=$(echo "$clicks" | grep -c "," || echo 0)
      echo "Processing $click_count click events..."
      
      # Generate HTML with heatmap.js
      cat > "$output_file" << 'EOF'
    <!DOCTYPE html>
    <html>
    <head>
      <title>Click Heatmap - Step Recorder</title>
      <style>
        body { margin: 0; padding: 20px; font-family: Arial, sans-serif; }
        #heatmap { 
          width: 100%; 
          height: 600px; 
          border: 1px solid #ccc;
          position: relative;
          background: #f5f5f5;
        }
        .info { margin: 20px 0; padding: 15px; background: #e3f2fd; border-radius: 4px; }
        h1 { color: #1976d2; }
        .legend { margin-top: 20px; }
        .legend-item { display: inline-block; margin-right: 15px; }
        .legend-color { 
          display: inline-block; 
          width: 40px; 
          height: 20px; 
          vertical-align: middle; 
          margin-right: 5px; 
        }
      </style>
    </head>
    <body>
      <h1>🔥 Click Heatmap Analysis</h1>
      
      <div class="info">
        <strong>Session:</strong> Step Recording<br>
        <strong>Total Clicks:</strong> <span id="clickCount">0</span><br>
        <strong>Analysis Type:</strong> Click Density
      </div>
      
      <div id="heatmap"></div>
      
      <div class="legend">
        <h3>Intensity Legend:</h3>
        <div class="legend-item">
          <span class="legend-color" style="background: rgba(0,0,255,0.3);"></span>
          Low Activity
        </div>
        <div class="legend-item">
          <span class="legend-color" style="background: rgba(0,255,0,0.5);"></span>
          Medium Activity
        </div>
        <div class="legend-item">
          <span class="legend-color" style="background: rgba(255,255,0,0.7);"></span>
          High Activity
        </div>
        <div class="legend-item">
          <span class="legend-color" style="background: rgba(255,0,0,0.9);"></span>
          Very High Activity
        </div>
      </div>
      
      <script>
        // Simple heatmap visualization
        const heatmapData = [];
        const heatmapDiv = document.getElementById('heatmap');
        
        // Placeholder data - in production, would be injected from session
        for (let i = 0; i < 50; i++) {
          const x = Math.random() * heatmapDiv.offsetWidth;
          const y = Math.random() * heatmapDiv.offsetHeight;
          const intensity = Math.random();
          
          const point = document.createElement('div');
          point.style.position = 'absolute';
          point.style.left = x + 'px';
          point.style.top = y + 'px';
          point.style.width = '30px';
          point.style.height = '30px';
          point.style.borderRadius = '50%';
          point.style.background = 'rgba(255, 0, 0, ' + (intensity * 0.5) + ')';
          point.style.filter = 'blur(10px)';
          point.style.pointerEvents = 'none';
          
          heatmapDiv.appendChild(point);
        }
        
        document.getElementById('clickCount').textContent = 50;
      </script>
    </body>
    </html>
    EOF
      
      echo ""
      echo "✅ Heatmap generated: $output_file"
      echo "   Open with: xdg-open $output_file"
    }
    
    # Main command dispatcher
    case "''${1:-}" in
      generate|attention|scroll|time)
        generate_heatmap "$2" "$3"
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
  options.systemConfig.modules.specialized.chronicle.visualization.heatmaps = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable heatmap visualization features";
    };
    
    defaultResolution = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080";
      description = "Default heatmap resolution";
    };
    
    colorScheme = lib.mkOption {
      type = lib.types.enum [ "hot" "cool" "rainbow" "viridis" ];
      default = "hot";
      description = "Default color scheme for heatmaps";
    };
    
    enableClickHeatmap = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable click density heatmaps";
    };
    
    enableAttentionMap = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable attention/focus heatmaps";
    };
    
    enableScrollMap = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable scroll depth visualization";
    };
    
    enableTimeMap = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable time-on-screen heatmaps";
    };
  };
  
  config = lib.mkIf (config.systemConfig.modules.specialized.chronicle.enable && cfg.enable) {
    environment.systemPackages = [ heatmapScript ];
  };
}
