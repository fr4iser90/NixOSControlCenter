{ lib, pkgs, cfg }:

{
  # Generate thumbnail gallery view HTML
  generateGallery = session_path: ''
    local session_id=$(basename "${session_path}")
    local steps_dir="${session_path}/steps"
    local screenshots_dir="${session_path}/screenshots"
    local gallery_file="${session_path}/gallery.html"
    
    # Read session metadata
    local session_data=$(cat "${session_path}/session.json")
    local problem_title=$(echo "$session_data" | ${pkgs.jq}/bin/jq -r '.problem_title // "No title"')
    local session_name=$(echo "$session_data" | ${pkgs.jq}/bin/jq -r '.session_name // "session"')
    local start_time=$(echo "$session_data" | ${pkgs.jq}/bin/jq -r '.start_time')
    
    cat > "$gallery_file" << 'GALLERY_HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Gallery - __SESSION_NAME__</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
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
    .header .meta { color: #666; font-size: 14px; }
    .gallery {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }
    .thumbnail {
      background: white;
      border-radius: 10px;
      overflow: hidden;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      transition: transform 0.2s, box-shadow 0.2s;
      cursor: pointer;
    }
    .thumbnail:hover {
      transform: translateY(-5px);
      box-shadow: 0 5px 20px rgba(0,0,0,0.2);
    }
    .thumbnail img {
      width: 100%;
      height: 200px;
      object-fit: cover;
      border-bottom: 1px solid #eee;
    }
    .thumbnail .info {
      padding: 15px;
    }
    .thumbnail .step-num {
      font-weight: bold;
      color: #0066cc;
      font-size: 18px;
      margin-bottom: 5px;
    }
    .thumbnail .description {
      color: #666;
      font-size: 14px;
      line-height: 1.4;
      margin-bottom: 8px;
    }
    .thumbnail .action {
      display: inline-block;
      background: #f0f0f0;
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 12px;
      color: #666;
    }
    .thumbnail .timestamp {
      color: #999;
      font-size: 12px;
      margin-top: 8px;
    }
    .lightbox {
      display: none;
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0,0,0,0.9);
      z-index: 1000;
      padding: 40px;
    }
    .lightbox.active { display: flex; align-items: center; justify-content: center; }
    .lightbox-content {
      max-width: 90%;
      max-height: 90%;
      background: white;
      border-radius: 10px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }
    .lightbox img {
      max-width: 100%;
      max-height: 70vh;
      object-fit: contain;
    }
    .lightbox-info {
      padding: 20px;
      background: white;
    }
    .close-btn {
      position: absolute;
      top: 20px;
      right: 20px;
      font-size: 40px;
      color: white;
      cursor: pointer;
      background: rgba(0,0,0,0.5);
      width: 50px;
      height: 50px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      line-height: 1;
    }
    .nav-btn {
      position: absolute;
      top: 50%;
      transform: translateY(-50%);
      font-size: 40px;
      color: white;
      cursor: pointer;
      background: rgba(0,0,0,0.5);
      width: 50px;
      height: 50px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .nav-btn.prev { left: 20px; }
    .nav-btn.next { right: 20px; }
    .comments {
      background: #f9f9f9;
      padding: 10px;
      margin-top: 10px;
      border-radius: 5px;
      font-size: 13px;
      color: #555;
    }
    .comment { margin-bottom: 5px; padding: 5px; background: white; border-radius: 3px; }
  </style>
</head>
<body>
  <div class="header">
    <h1>📸 __PROBLEM_TITLE__</h1>
    <div class="meta">
      Session: __SESSION_NAME__ | Started: __START_TIME__ | Total Steps: __TOTAL_STEPS__
    </div>
  </div>
  
  <div class="gallery" id="gallery">
    <!-- Thumbnails will be inserted here -->
  </div>
  
  <div class="lightbox" id="lightbox">
    <div class="close-btn" onclick="closeLightbox()">&times;</div>
    <div class="nav-btn prev" onclick="navigateStep(-1)">‹</div>
    <div class="nav-btn next" onclick="navigateStep(1)">›</div>
    <div class="lightbox-content" id="lightbox-content">
      <!-- Full view will be shown here -->
    </div>
  </div>
  
  <script>
    const steps = __STEPS_DATA__;
    let currentStep = 0;
    
    // Generate thumbnails
    const gallery = document.getElementById('gallery');
    steps.forEach((step, index) => {
      const thumb = document.createElement('div');
      thumb.className = 'thumbnail';
      thumb.onclick = () => openLightbox(index);
      
      let commentsHTML = '';
      if (step.comments && step.comments.length > 0) {
        commentsHTML = '<div class="comments">';
        step.comments.forEach(c => {
          commentsHTML += `<div class="comment">💬 ${c.comment}</div>`;
        });
        commentsHTML += '</div>';
      }
      
      thumb.innerHTML = `
        ${step.screenshot !== 'null' ? `<img src="screenshots/${step.screenshot}" alt="Step ${step.step}">` : '<div style="height:200px;background:#eee;display:flex;align-items:center;justify-content:center;">No Screenshot</div>'}
        <div class="info">
          <div class="step-num">Step ${step.step}</div>
          <div class="description">${step.description || 'No description'}</div>
          <span class="action">${step.action}</span>
          <div class="timestamp">${new Date(step.timestamp.replace(/_/g, ' ')).toLocaleString()}</div>
          ${commentsHTML}
        </div>
      `;
      gallery.appendChild(thumb);
    });
    
    function openLightbox(index) {
      currentStep = index;
      const step = steps[index];
      const content = document.getElementById('lightbox-content');
      
      let commentsHTML = '';
      if (step.comments && step.comments.length > 0) {
        commentsHTML = '<div class="comments">';
        step.comments.forEach(c => {
          commentsHTML += `<div class="comment">💬 ${c.comment} <small>(${new Date(c.timestamp).toLocaleString()})</small></div>`;
        });
        commentsHTML += '</div>';
      }
      
      content.innerHTML = `
        ${step.screenshot !== 'null' ? `<img src="screenshots/${step.screenshot}" alt="Step ${step.step}">` : ''}
        <div class="lightbox-info">
          <h2>Step ${step.step}: ${step.action}</h2>
          <p>${step.description || 'No description'}</p>
          <p><strong>Window:</strong> ${step.window_title}</p>
          <p><strong>App:</strong> ${step.app_name}</p>
          <p><strong>Time:</strong> ${new Date(step.timestamp.replace(/_/g, ' ')).toLocaleString()}</p>
          ${commentsHTML}
        </div>
      `;
      
      document.getElementById('lightbox').classList.add('active');
    }
    
    function closeLightbox() {
      document.getElementById('lightbox').classList.remove('active');
    }
    
    function navigateStep(direction) {
      currentStep = (currentStep + direction + steps.length) % steps.length;
      openLightbox(currentStep);
    }
    
    // Keyboard navigation
    document.addEventListener('keydown', (e) => {
      if (document.getElementById('lightbox').classList.contains('active')) {
        if (e.key === 'Escape') closeLightbox();
        if (e.key === 'ArrowLeft') navigateStep(-1);
        if (e.key === 'ArrowRight') navigateStep(1);
      }
    });
  </script>
</body>
</html>
GALLERY_HTML
    
    # Replace placeholders
    sed -i "s|__SESSION_NAME__|$session_name|g" "$gallery_file"
    sed -i "s|__PROBLEM_TITLE__|$problem_title|g" "$gallery_file"
    sed -i "s|__START_TIME__|$start_time|g" "$gallery_file"
    
    # Count total steps
    local total_steps=$(ls -1 "$steps_dir"/step_*.json 2>/dev/null | wc -l)
    sed -i "s|__TOTAL_STEPS__|$total_steps|g" "$gallery_file"
    
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
    
    # Escape JSON for JavaScript
    steps_json=$(echo "$steps_json" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    sed -i "s|__STEPS_DATA__|$steps_json|g" "$gallery_file"
    
    log "Gallery generated: $gallery_file"
  '';
}
