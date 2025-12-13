{ pkgs }:

pkgs.writeShellScriptBin "scan-browser" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  OUTPUT_FILE="$1"
  
  echo "🌐 Scanning browser extensions and settings..."
  
  BROWSERS=()
  
  # Firefox
  FIREFOX_PROFILES=(
    "$HOME/.mozilla/firefox"
    "$HOME/.var/app/org.mozilla.firefox/data/firefox"
  )
  
  for firefox_dir in "''${FIREFOX_PROFILES[@]}"; do
    if [ -d "$firefox_dir" ]; then
      # Find profiles
      while IFS= read -r profile_dir; do
        if [ -d "$profile_dir" ]; then
          PROFILE_NAME=$(basename "$profile_dir")
          
          # Scan extensions
          EXTENSIONS="[]"
          if [ -d "$profile_dir/extensions" ]; then
            while IFS= read -r ext_file; do
              if [ -f "$ext_file" ]; then
                # Try to extract extension ID and name from manifest
                EXT_ID=$(basename "$ext_file" .xpi 2>/dev/null || basename "$ext_file")
                EXT_NAME=""
                EXT_VERSION=""
                
                # If it's a directory, read manifest.json
                if [ -d "$ext_file" ] && [ -f "$ext_file/manifest.json" ]; then
                  EXT_NAME=$(${pkgs.jq}/bin/jq -r '.name // .applications.gecko.id // "Unknown"' "$ext_file/manifest.json" 2>/dev/null || echo "Unknown")
                  EXT_VERSION=$(${pkgs.jq}/bin/jq -r '.version // "Unknown"' "$ext_file/manifest.json" 2>/dev/null || echo "Unknown")
                fi
                
                EXT_JSON=$(${pkgs.jq}/bin/jq -n \
                  --arg id "$EXT_ID" \
                  --arg name "$EXT_NAME" \
                  --arg version "$EXT_VERSION" \
                  '{
                    id: $id,
                    name: $name,
                    version: $version
                  }')
                
                EXTENSIONS=$(${pkgs.jq}/bin/jq --argjson ext "$EXT_JSON" '. + [$ext]' <<< "$EXTENSIONS")
              fi
            done < <(find "$profile_dir/extensions" -type f -o -type d 2>/dev/null | head -50 || true)
          fi
          
          # Scan bookmarks
          BOOKMARKS="[]"
          if [ -f "$profile_dir/places.sqlite" ]; then
            # Firefox stores bookmarks in SQLite
            if command -v sqlite3 >/dev/null 2>&1; then
              # Get bookmarks from places.sqlite
              BOOKMARK_DATA=$(sqlite3 "$profile_dir/places.sqlite" "
                SELECT 
                  b.id,
                  b.title,
                  p.url,
                  b.dateAdded/1000000 as dateAdded
                FROM moz_bookmarks b
                JOIN moz_places p ON b.fk = p.id
                WHERE b.type = 1
                ORDER BY b.dateAdded DESC
                LIMIT 1000;
              " 2>/dev/null || echo "")
              
              if [ -n "$BOOKMARK_DATA" ]; then
                while IFS='|' read -r id title url dateAdded; do
                  if [ -n "$url" ]; then
                    BOOKMARK_JSON=$(${pkgs.jq}/bin/jq -n \
                      --arg title "$title" \
                      --arg url "$url" \
                      --arg dateAdded "$dateAdded" \
                      '{
                        title: $title,
                        url: $url,
                        dateAdded: $dateAdded
                      }')
                    
                    BOOKMARKS=$(${pkgs.jq}/bin/jq --argjson bookmark "$BOOKMARK_JSON" '. + [$bookmark]' <<< "$BOOKMARKS")
                  fi
                done <<< "$BOOKMARK_DATA"
              fi
            fi
          elif [ -f "$profile_dir/bookmarks.html" ]; then
            # Fallback: Parse bookmarks.html (older format)
            BOOKMARK_COUNT=$(grep -c '<DT><A HREF=' "$profile_dir/bookmarks.html" 2>/dev/null || echo "0")
            BOOKMARKS=$(${pkgs.jq}/bin/jq -n --argjson count "$BOOKMARK_COUNT" '{note: "HTML format detected", count: $count}')
          fi
          
          # Browser settings (prefs.js)
          SETTINGS="{}"
          if [ -f "$profile_dir/prefs.js" ]; then
            # Extract some common settings (not all, as it's huge)
            SETTINGS=$(${pkgs.jq}/bin/jq -n \
              --arg prefsFile "$profile_dir/prefs.js" \
              '{
                prefsFile: $prefsFile,
                note: "Settings file exists, parse manually if needed"
              }')
          fi
          
          BROWSER_JSON=$(${pkgs.jq}/bin/jq -n \
            --arg name "Firefox" \
            --arg profile "$PROFILE_NAME" \
            --argjson extensions "$EXTENSIONS" \
            --argjson bookmarks "$BOOKMARKS" \
            --argjson settings "$SETTINGS" \
            '{
              browser: $name,
              profile: $profile,
              extensions: {
                count: ($extensions | length),
                items: $extensions
              },
              bookmarks: {
                count: (if ($bookmarks | type) == "array" then ($bookmarks | length) else 0 end),
                items: (if ($bookmarks | type) == "array" then $bookmarks else [] end)
              },
              settings: $settings
            }')
          
          BROWSERS+=("$BROWSER_JSON")
        fi
      done < <(find "$firefox_dir" -maxdepth 1 -type d -name "*.default*" -o -name "*.default-release" 2>/dev/null || true)
    fi
  done
  
  # Chrome/Chromium
  CHROME_PROFILES=(
    "$HOME/.config/google-chrome"
    "$HOME/.config/chromium"
    "$HOME/.var/app/com.google.Chrome/data/google-chrome"
    "$HOME/.var/app/org.chromium.Chromium/data/chromium"
  )
  
  for chrome_dir in "''${CHROME_PROFILES[@]}"; do
    if [ -d "$chrome_dir" ]; then
      BROWSER_NAME=$(basename "$chrome_dir" | sed 's/^google-//' | sed 's/^org\.//')
      
      # Find default profile
      DEFAULT_PROFILE=""
      if [ -d "$chrome_dir/Default" ]; then
        DEFAULT_PROFILE="Default"
      elif [ -d "$chrome_dir/Profile 1" ]; then
        DEFAULT_PROFILE="Profile 1"
      fi
      
      if [ -n "$DEFAULT_PROFILE" ] && [ -d "$chrome_dir/$DEFAULT_PROFILE" ]; then
        # Scan extensions
        EXTENSIONS="[]"
        if [ -d "$chrome_dir/$DEFAULT_PROFILE/Extensions" ]; then
          while IFS= read -r ext_dir; do
            if [ -d "$ext_dir" ]; then
              EXT_ID=$(basename "$ext_dir")
              
              # Find version directory
              VERSION_DIR=$(find "$ext_dir" -maxdepth 1 -type d ! -name "$EXT_ID" | head -1)
              if [ -n "$VERSION_DIR" ] && [ -f "$VERSION_DIR/manifest.json" ]; then
                EXT_NAME=$(${pkgs.jq}/bin/jq -r '.name // "Unknown"' "$VERSION_DIR/manifest.json" 2>/dev/null || echo "Unknown")
                EXT_VERSION=$(${pkgs.jq}/bin/jq -r '.version // "Unknown"' "$VERSION_DIR/manifest.json" 2>/dev/null || echo "Unknown")
                
                EXT_JSON=$(${pkgs.jq}/bin/jq -n \
                  --arg id "$EXT_ID" \
                  --arg name "$EXT_NAME" \
                  --arg version "$EXT_VERSION" \
                  '{
                    id: $id,
                    name: $name,
                    version: $version
                  }')
                
                EXTENSIONS=$(${pkgs.jq}/bin/jq --argjson ext "$EXT_JSON" '. + [$ext]' <<< "$EXTENSIONS")
              fi
            fi
          done < <(find "$chrome_dir/$DEFAULT_PROFILE/Extensions" -maxdepth 1 -type d 2>/dev/null | head -50 || true)
        fi
        
        # Bookmarks
        BOOKMARKS="[]"
        if [ -f "$chrome_dir/$DEFAULT_PROFILE/Bookmarks" ]; then
          # Chrome stores bookmarks in JSON format
          if ${pkgs.jq}/bin/jq empty "$chrome_dir/$DEFAULT_PROFILE/Bookmarks" 2>/dev/null; then
            # Extract bookmarks from JSON structure
            BOOKMARK_DATA=$(${pkgs.jq}/bin/jq -r '
              def extract_bookmarks: 
                if type == "object" then
                  if .type == "url" then
                    [{
                      title: .name,
                      url: .url,
                      dateAdded: (.date_added // "unknown")
                    }]
                  elif .children then
                    [.children[] | extract_bookmarks[]]
                  else
                    []
                  end
                elif type == "array" then
                  [.[] | extract_bookmarks[]]
                else
                  []
                end;
              
              [.roots | to_entries[] | .value | extract_bookmarks[]]
            ' "$chrome_dir/$DEFAULT_PROFILE/Bookmarks" 2>/dev/null || echo "[]")
            
            if [ -n "$BOOKMARK_DATA" ] && [ "$BOOKMARK_DATA" != "[]" ]; then
              BOOKMARKS="$BOOKMARK_DATA"
            fi
          fi
        fi
        
        BROWSER_JSON=$(${pkgs.jq}/bin/jq -n \
          --arg name "$BROWSER_NAME" \
          --arg profile "$DEFAULT_PROFILE" \
          --argjson extensions "$EXTENSIONS" \
          --argjson bookmarks "$BOOKMARKS" \
          '{
            browser: $name,
            profile: $profile,
            extensions: {
              count: ($extensions | length),
              items: $extensions
            },
            bookmarks: {
              count: (if ($bookmarks | type) == "array" then ($bookmarks | length) else 0 end),
              items: (if ($bookmarks | type) == "array" then $bookmarks else [] end)
            }
          }')
        
        BROWSERS+=("$BROWSER_JSON")
      fi
    fi
  done
  
  # Combine all browsers
  BROWSERS_JSON="[]"
  for browser in "''${BROWSERS[@]}"; do
    BROWSERS_JSON=$(${pkgs.jq}/bin/jq --argjson browser "$browser" '. + [$browser]' <<< "$BROWSERS_JSON")
  done
  
  # Output JSON
  ${pkgs.jq}/bin/jq -n \
    --argjson browsers "$BROWSERS_JSON" \
    '{
      browsers: {
        count: ($browsers | length),
        items: $browsers
      }
    }' > "$OUTPUT_FILE"
  
  BROWSER_COUNT=$(${pkgs.jq}/bin/jq '.browsers.count' "$OUTPUT_FILE")
  TOTAL_EXTENSIONS=$(${pkgs.jq}/bin/jq '[.browsers.items[].extensions.count] | add' "$OUTPUT_FILE")
  TOTAL_BOOKMARKS=$(${pkgs.jq}/bin/jq '[.browsers.items[].bookmarks.count] | add' "$OUTPUT_FILE")
  echo "✅ Found $BROWSER_COUNT browser(s) with $TOTAL_EXTENSIONS extensions and $TOTAL_BOOKMARKS bookmarks"
''

