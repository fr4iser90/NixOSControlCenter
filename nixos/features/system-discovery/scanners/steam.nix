{ pkgs }:

pkgs.writeShellScriptBin "scan-steam" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  OUTPUT_FILE="$1"
  
  echo "🎮 Scanning Steam games..."
  
  STEAM_DIRS=(
    "$HOME/.steam/steam"
    "$HOME/.local/share/Steam"
    "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
  )
  
  STEAM_PATH=""
  for dir in "''${STEAM_DIRS[@]}"; do
    if [ -d "$dir" ]; then
      STEAM_PATH="$dir"
      break
    fi
  done
  
  if [ -z "$STEAM_PATH" ]; then
    echo "⚠️  Steam not found, skipping..."
    echo "[]" > "$OUTPUT_FILE"
    exit 0
  fi
  
  # Find Steam library folders
  LIBRARY_FOLDERS=("$STEAM_PATH/steamapps")
  
  # Check for additional library folders in libraryfolders.vdf
  if [ -f "$STEAM_PATH/steamapps/libraryfolders.vdf" ]; then
    while IFS= read -r line; do
      if [[ "$line" =~ \"path\"[[:space:]]*\"([^\"]+)\" ]]; then
        LIB_PATH="''${BASH_REMATCH[1]}/steamapps"
        if [ -d "$LIB_PATH" ]; then
          LIBRARY_FOLDERS+=("$LIB_PATH")
        fi
      fi
    done < "$STEAM_PATH/steamapps/libraryfolders.vdf"
  fi
  
  # Collect installed games
  GAMES_JSON="[]"
  
  for lib_folder in "''${LIBRARY_FOLDERS[@]}"; do
    if [ ! -d "$lib_folder" ]; then
      continue
    fi
    
    # Find all appmanifest files
    while IFS= read -r manifest_file; do
      if [ ! -f "$manifest_file" ]; then
        continue
      fi
      
      APP_ID=$(basename "$manifest_file" | sed 's/appmanifest_\([0-9]*\)\.acf/\1/')
      APP_NAME=$(grep "name" "$manifest_file" 2>/dev/null | head -1 | sed 's/.*"name"[[:space:]]*"\([^"]*\)".*/\1/' || echo "Unknown")
      INSTALL_DIR=$(grep "installdir" "$manifest_file" 2>/dev/null | head -1 | sed 's/.*"installdir"[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
      
      if [ -n "$APP_ID" ] && [ "$APP_ID" != "manifest_file" ]; then
        GAME_JSON=$(${pkgs.jq}/bin/jq -n \
          --arg id "$APP_ID" \
          --arg name "$APP_NAME" \
          --arg dir "$INSTALL_DIR" \
          '{
            appId: $id,
            name: $name,
            installDir: $dir
          }')
        
        GAMES_JSON=$(${pkgs.jq}/bin/jq --argjson game "$GAME_JSON" '. + [$game]' <<< "$GAMES_JSON")
      fi
    done < <(find "$lib_folder" -name "appmanifest_*.acf" 2>/dev/null || true)
  done
  
  # Output JSON
  ${pkgs.jq}/bin/jq -n \
    --argjson games "$GAMES_JSON" \
    '{
      steam: {
        installed: ($games | length),
        games: $games
      }
    }' > "$OUTPUT_FILE"
  
  GAME_COUNT=$(${pkgs.jq}/bin/jq '.steam.installed' "$OUTPUT_FILE")
  echo "✅ Found $GAME_COUNT Steam games"
''

