{ pkgs, cfg, ui }:

let
  jq = "${pkgs.jq}/bin/jq";
in

pkgs.writeShellScriptBin "restore-snapshot" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  SNAPSHOT_FILE=""
  RESTORE_BROWSERS=false
  RESTORE_IDES=false
  RESTORE_DESKTOP=false
  DRY_RUN=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --snapshot)
        SNAPSHOT_FILE="$2"
        shift 2
        ;;
      --browsers)
        RESTORE_BROWSERS=true
        shift
        ;;
      --ides)
        RESTORE_IDES=true
        shift
        ;;
      --desktop)
        RESTORE_DESKTOP=true
        shift
        ;;
      --all)
        RESTORE_BROWSERS=true
        RESTORE_IDES=true
        RESTORE_DESKTOP=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  
  if [ -z "$SNAPSHOT_FILE" ] || [ ! -f "$SNAPSHOT_FILE" ]; then
    echo "Error: --snapshot file is required and must exist"
    exit 1
  fi
  
  # Decrypt if encrypted
  DECRYPTED_FILE="$SNAPSHOT_FILE"
  if [[ "$SNAPSHOT_FILE" == *.encrypted ]]; then
    ${ui.messages.info "Decrypting snapshot..."}
    DECRYPTED_FILE=$(mktemp)
    trap "rm -f $DECRYPTED_FILE" EXIT
    
    # Try sops first
    if command -v sops >/dev/null 2>&1 && sops -d "$SNAPSHOT_FILE" > "$DECRYPTED_FILE" 2>/dev/null; then
      ${ui.messages.success "Decrypted with sops"}
    # Try age (FIDO2)
    elif command -v age >/dev/null 2>&1; then
      if age -d -i "$HOME/.config/age/yubikey-identity.txt" "$SNAPSHOT_FILE" > "$DECRYPTED_FILE" 2>/dev/null; then
        ${ui.messages.success "Decrypted with age/FIDO2"}
      else
        ${ui.messages.error "Failed to decrypt snapshot"}
        exit 1
      fi
    else
      ${ui.messages.error "No decryption tool found (sops or age required)"}
      exit 1
    fi
  fi
  
  # Load snapshot data
  SNAPSHOT_DATA=$(cat "$DECRYPTED_FILE")
  
  ${ui.text.header "Restoring from Snapshot"}
  ${ui.tables.keyValue "Snapshot" "$SNAPSHOT_FILE"}
  ${ui.tables.keyValue "Timestamp" "$(echo \"$SNAPSHOT_DATA\" | ${jq} -r '.metadata.timestamp // \"unknown\"')"}
  
  # Restore browsers
  if [ "$RESTORE_BROWSERS" = "true" ]; then
    ${ui.text.newline}
    ${ui.text.subHeader "Restoring Browsers"}
    
    BROWSERS=$(echo "$SNAPSHOT_DATA" | ${jq} -c '.browsers.items[]?' || echo "")
    
    if [ -z "$BROWSERS" ]; then
      ${ui.messages.warning "No browser data found in snapshot"}
    else
      while IFS= read -r browser_json; do
        BROWSER_NAME=$(echo "$browser_json" | ${jq} -r '.browser // "unknown"')
        PROFILE=$(echo "$browser_json" | ${jq} -r '.profile // "default"')
        
        ${ui.text.normal "  $BROWSER_NAME ($PROFILE)"}
        
        # Restore Firefox bookmarks
        if [ "$BROWSER_NAME" = "Firefox" ]; then
          FIREFOX_PROFILES=(
            "$HOME/.mozilla/firefox"
            "$HOME/.var/app/org.mozilla.firefox/data/firefox"
          )
          
          for firefox_dir in "''${FIREFOX_PROFILES[@]}"; do
            if [ -d "$firefox_dir" ]; then
              PROFILE_DIR=$(find "$firefox_dir" -maxdepth 1 -type d -name "*$PROFILE*" | head -1)
              
              if [ -n "$PROFILE_DIR" ] && [ -d "$PROFILE_DIR" ]; then
                BOOKMARKS=$(echo "$browser_json" | ${jq} -c '.bookmarks.items[]?' || echo "")
                
                if [ -n "$BOOKMARKS" ] && [ -f "$PROFILE_DIR/places.sqlite" ]; then
                  ${ui.messages.info "    Restoring bookmarks..."}
                  
                  if [ "$DRY_RUN" = "false" ] && command -v sqlite3 >/dev/null 2>&1; then
                    # Backup existing database
                    cp "$PROFILE_DIR/places.sqlite" "$PROFILE_DIR/places.sqlite.backup.$(date +%s)"
                    
                    # Restore bookmarks
                    BOOKMARK_COUNT=0
                    while IFS= read -r bookmark_json; do
                      TITLE=$(echo "$bookmark_json" | ${jq} -r '.title // ""')
                      URL=$(echo "$bookmark_json" | ${jq} -r '.url // ""')
                      
                      if [ -n "$TITLE" ] && [ -n "$URL" ]; then
                        # Check if bookmark already exists
                        EXISTS=$(sqlite3 "$PROFILE_DIR/places.sqlite" "
                          SELECT COUNT(*) FROM moz_places WHERE url = '$URL';
                        " 2>/dev/null || echo "0")
                        
                        if [ "$EXISTS" = "0" ]; then
                          # Insert into places
                          sqlite3 "$PROFILE_DIR/places.sqlite" "
                            INSERT INTO moz_places (url, title, visit_count, last_visit_date)
                            VALUES ('$URL', '$TITLE', 0, $(date +%s)000000);
                          " 2>/dev/null
                          
                          # Get place ID and insert bookmark
                          PLACE_ID=$(sqlite3 "$PROFILE_DIR/places.sqlite" "
                            SELECT id FROM moz_places WHERE url = '$URL';
                          " 2>/dev/null)
                          
                          if [ -n "$PLACE_ID" ]; then
                            sqlite3 "$PROFILE_DIR/places.sqlite" "
                              INSERT INTO moz_bookmarks (type, fk, parent, title, dateAdded, lastModified)
                              VALUES (1, $PLACE_ID, 2, '$TITLE', $(date +%s)000000, $(date +%s)000000);
                            " 2>/dev/null
                            
                            BOOKMARK_COUNT=$((BOOKMARK_COUNT + 1))
                          fi
                        fi
                      fi
                    done <<< "$BOOKMARKS"
                    
                    ${ui.messages.success "    Restored $BOOKMARK_COUNT bookmarks"}
                  else
                    BOOKMARK_COUNT=$(echo "$browser_json" | ${jq} '.bookmarks.count // 0')
                    ${ui.messages.info "    Would restore $BOOKMARK_COUNT bookmarks (dry-run)"}
                  fi
                fi
              fi
            fi
          done
        fi
        
        # Restore Chrome/Chromium bookmarks
        if [[ "$BROWSER_NAME" =~ (Chrome|Chromium) ]]; then
          CHROME_DIRS=(
            "$HOME/.config/google-chrome"
            "$HOME/.config/chromium"
            "$HOME/.var/app/com.google.Chrome/data/google-chrome"
            "$HOME/.var/app/org.chromium.Chromium/data/chromium"
          )
          
          for chrome_dir in "''${CHROME_DIRS[@]}"; do
            if [ -d "$chrome_dir" ]; then
              PROFILE_DIR="$chrome_dir/$PROFILE"
              
              if [ -d "$PROFILE_DIR" ]; then
                BOOKMARKS=$(echo "$browser_json" | ${jq} -c '.bookmarks.items[]?' || echo "")
                
                if [ -n "$BOOKMARKS" ]; then
                  ${ui.messages.info "    Restoring bookmarks..."}
                  
                  if [ "$DRY_RUN" = "false" ]; then
                    # Backup existing bookmarks
                    if [ -f "$PROFILE_DIR/Bookmarks" ]; then
                      cp "$PROFILE_DIR/Bookmarks" "$PROFILE_DIR/Bookmarks.backup.$(date +%s)"
                    fi
                    
                    # Load existing bookmarks
                    EXISTING_BOOKMARKS=$(cat "$PROFILE_DIR/Bookmarks" 2>/dev/null || echo '{"roots":{}}')
                    
                    # Merge bookmarks
                    MERGED_BOOKMARKS=$(echo "$EXISTING_BOOKMARKS" | ${jq} --argjson new "$BOOKMARKS" '
                      .roots.bookmark_bar.children += ($new | map({
                        name: .title,
                        type: "url",
                        url: .url
                      }))
                    ')
                    
                    echo "$MERGED_BOOKMARKS" > "$PROFILE_DIR/Bookmarks"
                    
                    BOOKMARK_COUNT=$(echo "$BOOKMARKS" | ${jq} 'length')
                    ${ui.messages.success "    Restored $BOOKMARK_COUNT bookmarks"}
                  else
                    BOOKMARK_COUNT=$(echo "$browser_json" | ${jq} '.bookmarks.count // 0')
                    ${ui.messages.info "    Would restore $BOOKMARK_COUNT bookmarks (dry-run)"}
                  fi
                fi
              fi
            fi
          done
        fi
        
        # List extensions (can't auto-install, but show list)
        EXTENSIONS=$(echo "$browser_json" | ${jq} -c '.extensions.items[]?' || echo "")
        if [ -n "$EXTENSIONS" ]; then
          EXT_COUNT=$(echo "$browser_json" | ${jq} '.extensions.count // 0')
          ${ui.messages.info "    Found $EXT_COUNT extensions (install manually from browser store)"}
        fi
      done <<< "$BROWSERS"
    fi
  fi
  
  # Restore IDEs
  if [ "$RESTORE_IDES" = "true" ]; then
    ${ui.text.newline}
    ${ui.text.subHeader "Restoring IDEs"}
    
    IDES=$(echo "$SNAPSHOT_DATA" | ${jq} -c '.ides.items[]?' || echo "")
    
    if [ -z "$IDES" ]; then
      ${ui.messages.warning "No IDE data found in snapshot"}
    else
      while IFS= read -r ide_json; do
        IDE_NAME=$(echo "$ide_json" | ${jq} -r '.ide // "unknown"')
        IDE_PATH=$(echo "$ide_json" | ${jq} -r '.path // ""')
        
        ${ui.text.normal "  $IDE_NAME"}
        
        # VS Code settings
        if [[ "$IDE_NAME" =~ "VS Code" ]] && [ -n "$IDE_PATH" ] && [ -d "$IDE_PATH" ]; then
          SETTINGS=$(echo "$ide_json" | ${jq} '.settings // {}')
          
          if [ "$DRY_RUN" = "false" ] && [ "$SETTINGS" != "{}" ]; then
            SETTINGS_FILE="$IDE_PATH/User/settings.json"
            mkdir -p "$(dirname "$SETTINGS_FILE")"
            
            # Merge with existing settings
            if [ -f "$SETTINGS_FILE" ]; then
              EXISTING_SETTINGS=$(cat "$SETTINGS_FILE")
              MERGED_SETTINGS=$(echo "$SETTINGS $EXISTING_SETTINGS" | ${jq} -s '.[0] * .[1]')
              echo "$MERGED_SETTINGS" > "$SETTINGS_FILE"
            else
              echo "$SETTINGS" > "$SETTINGS_FILE"
            fi
            
            ${ui.messages.success "    Restored settings"}
          else
            ${ui.messages.info "    Would restore settings (dry-run)"}
          fi
        fi
        
        # List extensions/plugins
        EXTENSIONS=$(echo "$ide_json" | ${jq} -c '.extensions.items[]? // .plugins.items[]?' || echo "")
        if [ -n "$EXTENSIONS" ]; then
          EXT_COUNT=$(echo "$ide_json" | ${jq} '.extensions.count // .plugins.count // 0')
          ${ui.messages.info "    Found $EXT_COUNT extensions/plugins (install manually)"}
        fi
      done <<< "$IDES"
    fi
  fi
  
  # Restore desktop settings
  if [ "$RESTORE_DESKTOP" = "true" ]; then
    ${ui.text.newline}
    ${ui.text.subHeader "Restoring Desktop Settings"}
    
    DESKTOP=$(echo "$SNAPSHOT_DATA" | ${jq} '.desktop // {}')
    
    if [ "$DESKTOP" = "{}" ]; then
      ${ui.messages.warning "No desktop data found in snapshot"}
    else
      if [ "$DRY_RUN" = "false" ]; then
        # Restore theme settings
        if command -v gsettings >/dev/null 2>&1; then
          DARK_MODE=$(echo "$DESKTOP" | ${jq} -r '.theme.dark // false')
          CURSOR_THEME=$(echo "$DESKTOP" | ${jq} -r '.theme.cursor // ""')
          ICON_THEME=$(echo "$DESKTOP" | ${jq} -r '.theme.icon // ""')
          GTK_THEME=$(echo "$DESKTOP" | ${jq} -r '.theme.gtk // ""')
          
          if [ "$DARK_MODE" = "true" ]; then
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
          fi
          
          [ -n "$CURSOR_THEME" ] && gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" 2>/dev/null || true
          [ -n "$ICON_THEME" ] && gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
          [ -n "$GTK_THEME" ] && gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
          
          ${ui.messages.success "    Restored GNOME/GTK settings"}
        fi
        
        ${ui.messages.info "    Other desktop environments: restore manually from snapshot data"}
      else
        ${ui.messages.info "    Would restore desktop settings (dry-run)"}
      fi
    fi
  fi
  
  ${ui.text.newline}
  ${ui.messages.success "Restore complete!"}
  
  if [ "$DRY_RUN" = "true" ]; then
    ${ui.text.newline}
    ${ui.messages.info "This was a dry-run. Use without --dry-run to actually restore."}
  fi
''

