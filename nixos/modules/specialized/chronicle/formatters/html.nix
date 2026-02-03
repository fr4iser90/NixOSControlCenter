{ lib, pkgs }:

{
  exportHtml = { sessionDir, sessionId }: ''
    export_html() {
      local session_dir="${sessionDir}"
      local html_file="$session_dir/report.html"

      cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Step Recorder Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }
        .meta { background: #f8f9fa; padding: 15px; border-radius: 4px; margin-bottom: 20px; }
        .step { margin-bottom: 30px; border: 1px solid #e9ecef; border-radius: 4px; overflow: hidden; }
        .step-header { background: #007bff; color: white; padding: 10px 15px; font-weight: bold; }
        .step-content { padding: 15px; }
        .step-desc { font-size: 16px; margin-bottom: 15px; color: #495057; }
        .screenshot { text-align: center; margin: 15px 0; }
        .screenshot img { max-width: 100%; border: 1px solid #dee2e6; border-radius: 4px; cursor: pointer; transition: transform 0.2s; }
        .screenshot img:hover { transform: scale(1.02); }
        
        /* Lazy loading optimization */
        img[loading="lazy"] { opacity: 0; transition: opacity 0.3s; }
        img[loading="lazy"].loaded { opacity: 1; }
        
        /* Lightbox for full-size images */
        .lightbox { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); z-index: 1000; justify-content: center; align-items: center; }
        .lightbox.active { display: flex; }
        .lightbox img { max-width: 90%; max-height: 90%; object-fit: contain; }
        .lightbox-close { position: absolute; top: 20px; right: 20px; color: white; font-size: 30px; cursor: pointer; }
        .meta-info { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; }
        .meta-item { background: white; padding: 10px; border-radius: 4px; border-left: 3px solid #007bff; }
        .footer { margin-top: 30px; text-align: center; color: #6c757d; font-size: 12px; }
        .no-screenshot { padding: 10px; background: #fff3cd; border: 1px solid #ffc107; border-radius: 4px; color: #856404; text-align: center; }
    </style>
    <script>
        // Lazy loading images
        document.addEventListener('DOMContentLoaded', function() {
            const images = document.querySelectorAll('img[loading="lazy"]');
            const imageObserver = new IntersectionObserver((entries, observer) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const img = entry.target;
                        img.classList.add('loaded');
                        observer.unobserve(img);
                    }
                });
            });
            
            images.forEach(img => imageObserver.observe(img));
            
            // Lightbox functionality
            const screenshots = document.querySelectorAll('.screenshot img');
            screenshots.forEach(img => {
                img.addEventListener('click', function() {
                    showLightbox(this.src);
                });
            });
        });
        
        function showLightbox(src) {
            const lightbox = document.getElementById('lightbox');
            const lightboxImg = document.getElementById('lightbox-img');
            lightboxImg.src = src;
            lightbox.classList.add('active');
        }
        
        function closeLightbox() {
            document.getElementById('lightbox').classList.remove('active');
        }
        
        // Close lightbox on ESC key
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') closeLightbox();
        });
    </script>
</head>
<body>
    <div id="lightbox" class="lightbox" onclick="closeLightbox()">
        <span class="lightbox-close">&times;</span>
        <img id="lightbox-img" src="" alt="Full size">
    </div>
    <div class="container">
        <h1>📝 Problem Steps Recorder Report</h1>
EOF

      # Add session metadata
      local session_json="$session_dir/session.json"
      local start_time=$(${pkgs.jq}/bin/jq -r '.start_time' "$session_json")
      local end_time=$(${pkgs.jq}/bin/jq -r '.end_time // "Recording in progress"' "$session_json")
      local backend=$(${pkgs.jq}/bin/jq -r '.backend' "$session_json")
      local hostname=$(${pkgs.jq}/bin/jq -r '.hostname' "$session_json")
      local user=$(${pkgs.jq}/bin/jq -r '.user' "$session_json")
      local total_steps=$(${pkgs.jq}/bin/jq -r '.total_steps // "Recording in progress"' "$session_json")

      cat >> "$html_file" << EOF
        <div class="meta">
            <div class="meta-info">
                <div class="meta-item"><strong>Session ID:</strong> ${sessionId}</div>
                <div class="meta-item"><strong>Start Time:</strong> $start_time</div>
                <div class="meta-item"><strong>End Time:</strong> $end_time</div>
                <div class="meta-item"><strong>Backend:</strong> $backend</div>
                <div class="meta-item"><strong>Hostname:</strong> $hostname</div>
                <div class="meta-item"><strong>User:</strong> $user</div>
                <div class="meta-item"><strong>Total Steps:</strong> $total_steps</div>
            </div>
        </div>
EOF

      # Add steps
      local steps_dir="$session_dir/steps"
      if [ -d "$steps_dir" ]; then
        for step_file in "$steps_dir"/step_*.json; do
          if [ -f "$step_file" ]; then
            local step_num=$(${pkgs.jq}/bin/jq -r '.step' "$step_file")
            local description=$(${pkgs.jq}/bin/jq -r '.description' "$step_file")
            local screenshot=$(${pkgs.jq}/bin/jq -r '.screenshot' "$step_file")
            local window_title=$(${pkgs.jq}/bin/jq -r '.window_title' "$step_file")
            local app_name=$(${pkgs.jq}/bin/jq -r '.app_name' "$step_file")

            cat >> "$html_file" << EOF
        <div class="step">
            <div class="step-header">Step $step_num - $window_title ($app_name)</div>
            <div class="step-content">
                <div class="step-desc">$description</div>
EOF

            if [ "$screenshot" != "null" ] && [ -n "$screenshot" ]; then
              cat >> "$html_file" << EOF
                <div class="screenshot">
                    <img src="steps/$screenshot" alt="Step $step_num Screenshot" loading="lazy">
                </div>
EOF
            else
              cat >> "$html_file" << EOF
                <div class="no-screenshot">📷 No screenshot available for this step</div>
EOF
            fi

            cat >> "$html_file" << EOF
            </div>
        </div>
EOF
          fi
        done
      fi

      cat >> "$html_file" << 'EOF'
        <div class="footer">
            Generated by NixOS Step Recorder - Privacy-focused problem documentation tool
        </div>
    </div>
</body>
</html>
EOF

      log "HTML report generated: $html_file"

      # Auto-open HTML in browser
      if command -v xdg-open &> /dev/null; then
        xdg-open "$html_file" &>/dev/null &
        log "Opening report in browser..."
      fi
    }
  '';
}
