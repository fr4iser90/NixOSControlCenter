{ lib, pkgs, cfg }:

{
  # Step comments and annotations functionality
  comments = ''
    # Add comment to a step
    add_comment_to_step() {
      local step_num="''${1:-$STEP_COUNT}"
      local comment="$2"
      local step_file="$OUTPUT_DIR/$SESSION_ID/steps/step_''${step_num}.json"
      
      if [ ! -f "$step_file" ]; then
        error "Step $step_num does not exist"
        return 1
      fi
      
      # Add comment to step metadata
      ${pkgs.jq}/bin/jq --arg comment "$comment" --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        '.comments += [{comment: $comment, timestamp: $timestamp, user: env.USER}]' \
        "$step_file" > "$step_file.tmp"
      mv "$step_file.tmp" "$step_file"
      
      log "💬 Comment added to step $step_num"
      notify_comment_added "$step_num"
    }
    
    # Interactive comment dialog
    add_comment_dialog() {
      load_state || {
        notify_error "No active recording. Start a recording first."
        return 1
      }
      
      local comment=""
      
      # Try GUI dialog first
      if command -v zenity &> /dev/null; then
        comment=$(${pkgs.zenity}/bin/zenity --entry \
          --title="Step Recorder - Add Comment" \
          --text="Add comment to current step ($STEP_COUNT):" \
          --entry-text="" 2>/dev/null || echo "")
      elif command -v kdialog &> /dev/null; then
        comment=$(${pkgs.kdePackages.kdialog}/bin/kdialog --inputbox \
          "Add comment to current step ($STEP_COUNT):" \
          "" 2>/dev/null || echo "")
      else
        # Fallback to command line
        read -p "Comment for step $STEP_COUNT: " comment
      fi
      
      if [ -n "$comment" ]; then
        add_comment_to_step "$STEP_COUNT" "$comment"
      fi
    }
    
    # Add annotation (highlight region) to screenshot
    add_annotation() {
      local step_num="$1"
      local annotation_type="''${2:-box}"  # box, arrow, circle, text
      local x="$3"
      local y="$4"
      local width="$5"
      local height="$6"
      local text="''${7:-}"
      
      local step_file="$OUTPUT_DIR/$SESSION_ID/steps/step_''${step_num}.json"
      local screenshot_file=$(${pkgs.jq}/bin/jq -r '.screenshot' "$step_file")
      
      if [ "$screenshot_file" = "null" ] || [ -z "$screenshot_file" ]; then
        warn "No screenshot for step $step_num to annotate"
        return 1
      fi
      
      # Store annotation metadata
      local annotation_json=$(cat << EOF
{
  "type": "$annotation_type",
  "x": $x,
  "y": $y,
  "width": $width,
  "height": $height,
  "text": "$text",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF
)
      
      ${pkgs.jq}/bin/jq --argjson annotation "$annotation_json" \
        '.annotations += [$annotation]' \
        "$step_file" > "$step_file.tmp"
      mv "$step_file.tmp" "$step_file"
      
      debug "Annotation added to step $step_num"
    }
    
    # Quick annotation - add text overlay to most recent screenshot
    quick_annotate() {
      local text="$1"
      
      if [ $STEP_COUNT -eq 0 ]; then
        warn "No steps captured yet"
        return 1
      fi
      
      add_comment_to_step "$STEP_COUNT" "$text"
    }
  '';
  
  # Annotation rendering (for export)
  renderAnnotations = ''
    # Render annotations on screenshot using ImageMagick
    render_annotations_on_image() {
      local step_num="$1"
      local step_file="$OUTPUT_DIR/$SESSION_ID/steps/step_''${step_num}.json"
      local screenshot_path="$OUTPUT_DIR/$SESSION_ID/screenshots"
      
      if [ ! -f "$step_file" ]; then
        return 1
      fi
      
      local screenshot_file=$(${pkgs.jq}/bin/jq -r '.screenshot' "$step_file")
      if [ "$screenshot_file" = "null" ]; then
        return 1
      fi
      
      local full_screenshot_path="$screenshot_path/$screenshot_file"
      if [ ! -f "$full_screenshot_path" ]; then
        return 1
      fi
      
      # Check if annotations exist
      local annotation_count=$(${pkgs.jq}/bin/jq '.annotations | length' "$step_file" 2>/dev/null || echo "0")
      if [ "$annotation_count" -eq 0 ]; then
        return 0
      fi
      
      # Create annotated version
      local annotated_file="''${full_screenshot_path%.png}_annotated.png"
      cp "$full_screenshot_path" "$annotated_file"
      
      # Render each annotation
      ${pkgs.jq}/bin/jq -c '.annotations[]' "$step_file" 2>/dev/null | while read -r annotation; do
        local type=$(echo "$annotation" | ${pkgs.jq}/bin/jq -r '.type')
        local x=$(echo "$annotation" | ${pkgs.jq}/bin/jq -r '.x')
        local y=$(echo "$annotation" | ${pkgs.jq}/bin/jq -r '.y')
        local width=$(echo "$annotation" | ${pkgs.jq}/bin/jq -r '.width')
        local height=$(echo "$annotation" | ${pkgs.jq}/bin/jq -r '.height')
        local text=$(echo "$annotation" | ${pkgs.jq}/bin/jq -r '.text')
        
        case "$type" in
          box)
            ${pkgs.imagemagick}/bin/convert "$annotated_file" \
              -stroke red -strokewidth 3 -fill none \
              -draw "rectangle $x,$y $((x+width)),$((y+height))" \
              "$annotated_file"
            ;;
          circle)
            local radius=$((width/2))
            local cx=$((x+radius))
            local cy=$((y+radius))
            ${pkgs.imagemagick}/bin/convert "$annotated_file" \
              -stroke red -strokewidth 3 -fill none \
              -draw "circle $cx,$cy $((cx+radius)),$cy" \
              "$annotated_file"
            ;;
          arrow)
            ${pkgs.imagemagick}/bin/convert "$annotated_file" \
              -stroke red -strokewidth 3 -fill red \
              -draw "line $x,$y $((x+width)),$((y+height))" \
              "$annotated_file"
            ;;
          text)
            ${pkgs.imagemagick}/bin/convert "$annotated_file" \
              -pointsize 24 -fill red -stroke black -strokewidth 1 \
              -annotate +$x+$y "$text" \
              "$annotated_file"
            ;;
        esac
      done
      
      debug "Rendered annotations for step $step_num"
    }
  '';
}
