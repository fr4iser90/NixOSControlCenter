{ lib, pkgs, cfg }:

{
  # Generate timeline view HTML
  generateTimeline = session_path: ''
    local session_id=$(basename "${session_path}")
    local steps_dir="${session_path}/steps"
    local timeline_file="${session_path}/timeline.html"
    
    # Read session metadata
    local session_data=$(cat "${session_path}/session.json")
    local problem_title=$(echo "$session_data" | ${pkgs.jq}/bin/jq -r '.problem_title // "No title"')
    local session_name=$(echo "$session_data" | ${pkgs.jq}/bin/jq -r '.session_name // "session"')
    local start_time=$(echo "$session_data" | ${pkgs.jq}/bin/jq -r '.start_time')
    
    cat > "$timeline_file" << 'TIMELINE_HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Timeline - __SESSION_NAME__</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f5f5f5;
      padding: 20px;
    }
    .header {
      background: white;
      padding: 30px;
      border-radius: 10px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      margin-bottom: 30px;
    }
    .header h1 { color: #333; margin-bottom: 10px; }
    .timeline-container {
      position: relative;
      padding: 20px 0;
    }
    .timeline-axis {
      position: relative;
      height: 4px;
      background: linear-gradient(to right, #0066cc, #00cc66);
      margin: 40px 0;
      border-radius: 2px;
    }
    .timeline-item {
      position: relative;
      margin-bottom: 60px;
    }
    .timeline-dot {
      width: 20px;
      height: 20px;
      background: #0066cc;
      border: 4px solid white;
      border-radius: 50%;
      position: absolute;
      top: -8px;
      box-shadow: 0 2px 5px rgba(0,0,0,0.2);
      cursor: pointer;
      transition: all 0.3s;
    }
    .timeline-dot:hover {
      transform: scale(1.3);
      background: #0099ff;
    }
    .timeline-dot.action-click { background: #ff6600; }
    .timeline-dot.action-right-click { background: #0066ff; }
    .timeline-dot.action-scroll-up,
    .timeline-dot.action-scroll-down { background: #9966ff; }
    .timeline-content {
      background: white;
      padding: 20px;
      border-radius: 10px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      margin-top: 40px;
      position: relative;
    }
    .timeline-content::before {
      content: '';
      position: absolute;
      top: -10px;
      left: 20px;
      width: 0;
      height: 0;
      border-left: 10px solid transparent;
      border-right: 10px solid transparent;
      border-bottom: 10px solid white;
    }
    .step-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 15px;
      padding-bottom: 10px;
      border-bottom: 2px solid #f0f0f0;
    }
    .step-num {
      font-size: 24px;
      font-weight: bold;
      color: #0066cc;
    }
    .step-time {
      color: #999;
      font-size: 14px;
    }
    .step-action {
      display: inline-block;
      background: #f0f0f0;
      padding: 6px 12px;
      border-radius: 5px;
      font-size: 13px;
      font-weight: 500;
      color: #666;
      margin-bottom: 10px;
    }
    .step-description {
      color: #555;
      line-height: 1.6;
      margin-bottom: 15px;
    }
    .step-screenshot {
      margin-top: 15px;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    .step-screenshot img {
      width: 100%;
      max-width: 800px;
      cursor: pointer;
      transition: transform 0.2s;
    }
    .step-screenshot img:hover {
      transform: scale(1.02);
    }
    .comments {
      background: #f9f9f9;
      padding: 15px;
      margin-top: 15px;
      border-radius: 8px;
      border-left: 4px solid #0066cc;
    }
    .comment {
      margin-bottom: 10px;
      padding: 10px;
      background: white;
      border-radius: 5px;
    }
    .comment-text {
      color: #333;
      margin-bottom: 5px;
    }
    .comment-meta {
      color: #999;
      font-size: 12px;
    }
    .window-info {
      display: flex;
      gap: 20px;
      margin-top: 10px;
      padding: 10px;
      background: #f9f9f9;
      border-radius: 5px;
      font-size: 13px;
    }
    .window-info span {
      color: #666;
    }
    .window-info strong {
      color: #333;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>📅 Timeline: __PROBLEM_TITLE__</h1>
    <div class="meta">
      Session: __SESSION_NAME__ | Started: __START_TIME__ | Total Steps: __TOTAL_STEPS__
    </div>
  </div>
  
  <div class="timeline-container">
    <div class="timeline-axis" id="timeline-axis"></div>
    <div id="timeline-items"></div>
  </div>
  
  <script>
    const steps = __STEPS_DATA__;
    
    // Calculate time ranges
    const startTime = new Date(steps[0].timestamp.replace(/_/g, ' ')).getTime();
    const endTime = new Date(steps[steps.length - 1].timestamp.replace(/_/g, ' ')).getTime();
    const totalDuration = endTime - startTime;
    
    const timelineAxis = document.getElementById('timeline-axis');
    const timelineItems = document.getElementById('timeline-items');
    
    steps.forEach((step, index) => {
      const stepTime = new Date(step.timestamp.replace(/_/g, ' ')).getTime();
      const position = totalDuration > 0 ? ((stepTime - startTime) / totalDuration) * 100 : (index / steps.length) * 100;
      
      // Create timeline dot
      const dot = document.createElement('div');
      dot.className = 'timeline-dot action-' + step.action;
      dot.style.left = position + '%';
      dot.title = 'Step ' + step.step + ': ' + step.action;
      dot.onclick = () => {
        document.getElementById('step-' + step.step).scrollIntoView({ behavior: 'smooth', block: 'center' });
      };
      timelineAxis.appendChild(dot);
      
      // Create timeline content
      const item = document.createElement('div');
      item.className = 'timeline-item';
      item.id = 'step-' + step.step;
      
      let commentsHTML = '';
      if (step.comments && step.comments.length > 0) {
        commentsHTML = '<div class="comments"><strong>💬 Comments:</strong>';
        step.comments.forEach(c => {
          commentsHTML += `
            <div class="comment">
              <div class="comment-text">${c.comment}</div>
              <div class="comment-meta">by ${c.user} at ${new Date(c.timestamp).toLocaleString()}</div>
            </div>
          `;
        });
        commentsHTML += '</div>';
      }
      
      item.innerHTML = `
        <div class="timeline-content">
          <div class="step-header">
            <div class="step-num">Step ${step.step}</div>
            <div class="step-time">${new Date(step.timestamp.replace(/_/g, ' ')).toLocaleString()}</div>
          </div>
          <div class="step-action">${step.action}</div>
          <div class="step-description">${step.description || 'No description'}</div>
          <div class="window-info">
            <span><strong>Window:</strong> ${step.window_title}</span>
            <span><strong>App:</strong> ${step.app_name}</span>
          </div>
          ${step.screenshot !== 'null' ? `
            <div class="step-screenshot">
              <img src="screenshots/${step.screenshot}" alt="Step ${step.step}" onclick="window.open(this.src, '_blank')">
            </div>
          ` : ''}
          ${commentsHTML}
        </div>
      `;
      
      timelineItems.appendChild(item);
    });
  </script>
</body>
</html>
TIMELINE_HTML
    
    # Replace placeholders (same as gallery)
    sed -i "s|__SESSION_NAME__|$session_name|g" "$timeline_file"
    sed -i "s|__PROBLEM_TITLE__|$problem_title|g" "$timeline_file"
    sed -i "s|__START_TIME__|$start_time|g" "$timeline_file"
    
    local total_steps=$(ls -1 "$steps_dir"/step_*.json 2>/dev/null | wc -l)
    sed -i "s|__TOTAL_STEPS__|$total_steps|g" "$timeline_file"
    
    # Generate steps data JSON
    local steps_json="["
    local first=true
    for step_file in "$steps_dir"/step_*.json; do
      [ -f "$step_file" ] || continue
      if [ "$first" = true ]; then
        first=false
      else
        steps_json+=","
      fi
      steps_json+=$(cat "$step_file")
    done
    steps_json+="]"
    
    steps_json=$(echo "$steps_json" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    sed -i "s|__STEPS_DATA__|$steps_json|g" "$timeline_file"
    
    log "Timeline generated: $timeline_file"
  '';
}
