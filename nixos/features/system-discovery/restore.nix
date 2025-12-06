{ pkgs, cfg, ui }:

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
  ${ui.tables.keyValue "Timestamp" "$(${pkgs.jq}/bin/jq -r '.metadata.timestamp // "unknown"' <<< "$SNAPSHOT_DATA")"}
  
  # Restore browsers
  if [ "$RESTORE_BROWSERS" = "true" ]; then
    ${ui.text.newline}
    ${ui.text.subHeader "Restoring Browsers"}
    
    BROWSERS=$(${pkgs.jq}/bin/jq -c '.browsers.items[]?' <<< "$SNAPSHOT_DATA" || echo "")
    
    if [ -z "$BROWSERS" ]; then
      ${ui.messages.warning "No browser data found in snapshot"}
    else
      while IFS= read -r browser_json; do
        BROWSER_NAME=$(${pkgs.jq}/bin/jq -r '.browser // "unknown"' <<< "$browser_json")
        PROFILE=$(${pkgs.jq}/bin/jq -r '.profile // "default"' <<< "$browser_json")
        
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
                BOOKMARKS=$(${pkgs.jq}/bin/jq -c '.bookmarks.items[]?' <<< "$browser_json" || echo "")
                
                if [ -n "$BOOKMARKS" ] && [ -f "$PROFILE_DIR/places.sqlite" ]; then
                  ${ui.messages.info "    Restoring bookmarks..."}
                  
                  if [ "$DRY_RUN" = "false" ] && command -v sqlite3 >/dev/null 2>&1; then
                    # Backup existing database
                    cp "$PROFILE_DIR/places.sqlite" "$PROFILE_DIR/places.sqlite.backup.$(date +%s)"
                    
                    # Restore bookmarks
                    BOOKMARK_COUNT=0
                    while IFS= read -r bookmark_json; do
                      TITLE=$(${pkgs.jq}/bin/jq -r '.title // ""' <<< "$bookmark_json")
                      URL=$(${pkgs.jq}/bin/jq -r '.url // ""' <<< "$bookmark_json")
                      
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
                    BOOKMARK_COUNT=$(${pkgs.jq}/bin/jq '.bookmarks.count // 0' <<< "$browser_json")
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
                BOOKMARKS=$(${pkgs.jq}/bin/jq -c '.bookmarks.items[]?' <<< "$browser_json" || echo "")
                
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
                    MERGED_BOOKMARKS=$(${pkgs.jq}/bin/jq --argjson new "$BOOKMARKS" '
                      .roots.bookmark_bar.children += ($new | map({
                        name: .title,
                        type: "url",
                        url: .url
                      }))
                    ' <<< "$EXISTING_BOOKMARKS")
                    
                    echo "$MERGED_BOOKMARKS" > "$PROFILE_DIR/Bookmarks"
                    
                    BOOKMARK_COUNT=$(${pkgs.jq}/bin/jq 'length' <<< "$BOOKMARKS")
                    ${ui.messages.success "    Restored $BOOKMARK_COUNT bookmarks"}
                  else
                    BOOKMARK_COUNT=$(${pkgs.jq}/bin/jq '.bookmarks.count // 0' <<< "$browser_json")
                    ${ui.messages.info "    Would restore $BOOKMARK_COUNT bookmarks (dry-run)"}
                  fi
                fi
              fi
            fi
          done
        fi
        
        # List extensions (can't auto-install, but show list)
        EXTENSIONS=$(${pkgs.jq}/bin/jq -c '.extensions.items[]?' <<< "$browser_json" || echo "")
        if [ -n "$EXTENSIONS" ]; then
          EXT_COUNT=$(${pkgs.jq}/bin/jq '.extensions.count // 0' <<< "$browser_json")
          ${ui.messages.info "    Found $EXT_COUNT extensions (install manually from browser store)"}
        fi
      done <<< "$BROWSERS"
    fi
  fi
  
  # Restore IDEs
  if [ "$RESTORE_IDES" = "true" ]; then
    ${ui.text.newline}
    ${ui.text.subHeader "Restoring IDEs"}
    
    IDES=$(${pkgs.jq}/bin/jq -c '.ides.items[]?' <<< "$SNAPSHOT_DATA" || echo "")
    
    if [ -z "$IDES" ]; then
      ${ui.messages.warning "No IDE data found in snapshot"}
    else
      while IFS= read -r ide_json; do
        IDE_NAME=$(${pkgs.jq}/bin/jq -r '.ide // "unknown"' <<< "$ide_json")
        IDE_PATH=$(${pkgs.jq}/bin/jq -r '.path // ""' <<< "$ide_json")
        
        ${ui.text.normal "  $IDE_NAME"}
        
        # VS Code settings
        if [[ "$IDE_NAME" =~ "VS Code" ]] && [ -n "$IDE_PATH" ] && [ -d "$IDE_PATH" ]; then
          SETTINGS=$(${pkgs.jq}/bin/jq '.settings // {}' <<< "$ide_json")
          
          if [ "$DRY_RUN" = "false" ] && [ "$SETTINGS" != "{}" ]; then
            SETTINGS_FILE="$IDE_PATH/User/settings.json"
            mkdir -p "$(dirname "$SETTINGS_FILE")"
            
            # Merge with existing settings
            if [ -f "$SETTINGS_FILE" ]; then
              EXISTING_SETTINGS=$(cat "$SETTINGS_FILE")
              MERGED_SETTINGS=$(${pkgs.jq}/bin/jq -s '.[0] * .[1]' <<< "$SETTINGS $EXISTING_SETTINGS")
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
        EXTENSIONS=$(${pkgs.jq}/bin/jq -c '.extensions.items[]? // .plugins.items[]?' <<< "$ide_json" || echo "")
        if [ -n "$EXTENSIONS" ]; then
          EXT_COUNT=$(${pkgs.jq}/bin/jq '.extensions.count // .plugins.count // 0' <<< "$ide_json")
          ${ui.messages.info "    Found $EXT_COUNT extensions/plugins (install manually)"}
        fi
      done <<< "$IDES"
    fi
  fi
  
  # Restore desktop settings
  if [ "$RESTORE_DESKTOP" = "true" ]; then
    ${ui.text.newline}
    ${ui.text.subHeader "Restoring Desktop Settings"}
    
    DESKTOP=$(${pkgs.jq}/bin/jq '.desktop // {}' <<< "$SNAPSHOT_DATA")
    
    if [ "$DESKTOP" = "{}" ]; then
      ${ui.messages.warning "No desktop data found in snapshot"}
    else
      if [ "$DRY_RUN" = "false" ]; then
        # Restore theme settings
        if command -v gsettings >/dev/null 2>&1; then
          DARK_MODE=$(${pkgs.jq}/bin/jq -r '.theme.dark // false' <<< "$DESKTOP")
          CURSOR_THEME=$(${pkgs.jq}/bin/jq -r '.theme.cursor // ""' <<< "$DESKTOP")
          ICON_THEME=$(${pkgs.jq}/bin/jq -r '.theme.icon // ""' <<< "$DESKTOP")
          GTK_THEME=$(${pkgs.jq}/bin/jq -r '.theme.gtk // ""' <<< "$DESKTOP")
          
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

