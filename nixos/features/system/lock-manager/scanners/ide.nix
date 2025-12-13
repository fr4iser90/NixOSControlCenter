{ pkgs }:

pkgs.writeShellScriptBin "scan-ide" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  OUTPUT_FILE="$1"
  
  echo "💻 Scanning IDE extensions and settings..."
  
  IDES=()
  
  # VS Code / VSCodium
  VSCODE_DIRS=(
    "$HOME/.config/Code"
    "$HOME/.config/VSCode"
    "$HOME/.config/codium"
    "$HOME/.var/app/com.vscode.codium/data/codium"
    "$HOME/.var/app/com.visualstudio.code/data/Code"
  )
  
  for vscode_dir in "''${VSCODE_DIRS[@]}"; do
    if [ -d "$vscode_dir" ]; then
      IDE_NAME=$(basename "$vscode_dir" | sed 's/^com\.//' | sed 's/^visualstudio\.//')
      
      # Scan extensions
      EXTENSIONS="[]"
      if [ -d "$vscode_dir/User/extensions" ] || [ -d "$vscode_dir/extensions" ]; then
        EXT_DIR="$vscode_dir/User/extensions"
        [ ! -d "$EXT_DIR" ] && EXT_DIR="$vscode_dir/extensions"
        
        if [ -d "$EXT_DIR" ]; then
          while IFS= read -r ext_dir; do
            if [ -d "$ext_dir" ] && [ -f "$ext_dir/package.json" ]; then
              EXT_NAME=$(${pkgs.jq}/bin/jq -r '.displayName // .name // "Unknown"' "$ext_dir/package.json" 2>/dev/null || echo "Unknown")
              EXT_ID=$(${pkgs.jq}/bin/jq -r '.publisher + "." + .name' "$ext_dir/package.json" 2>/dev/null || basename "$ext_dir")
              EXT_VERSION=$(${pkgs.jq}/bin/jq -r '.version // "Unknown"' "$ext_dir/package.json" 2>/dev/null || echo "Unknown")
              
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
          done < <(find "$EXT_DIR" -maxdepth 1 -type d 2>/dev/null | head -100 || true)
        fi
      fi
      
      # Settings
      SETTINGS="{}"
      if [ -f "$vscode_dir/User/settings.json" ]; then
        # Extract some key settings (not all, as it can be huge)
        SETTINGS=$(${pkgs.jq}/bin/jq '{
          theme: ."workbench.colorTheme",
          fontSize: ."editor.fontSize",
          fontFamily: ."editor.fontFamily",
          wordWrap: ."editor.wordWrap",
          minimap: ."editor.minimap.enabled"
        }' "$vscode_dir/User/settings.json" 2>/dev/null || echo "{}")
      fi
      
      # Keybindings
      KEYBINDINGS="[]"
      if [ -f "$vscode_dir/User/keybindings.json" ]; then
        KEYBINDINGS_COUNT=$(${pkgs.jq}/bin/jq 'length' "$vscode_dir/User/keybindings.json" 2>/dev/null || echo "0")
        KEYBINDINGS=$(${pkgs.jq}/bin/jq -n --argjson count "$KEYBINDINGS_COUNT" '{customKeybindings: $count}')
      fi
      
      IDE_JSON=$(${pkgs.jq}/bin/jq -n \
        --arg name "VS Code" \
        --arg path "$vscode_dir" \
        --argjson extensions "$EXTENSIONS" \
        --argjson settings "$SETTINGS" \
        --argjson keybindings "$KEYBINDINGS" \
        '{
          ide: $name,
          path: $path,
          extensions: {
            count: ($extensions | length),
            items: $extensions
          },
          settings: $settings,
          keybindings: $keybindings
        }')
      
      IDES+=("$IDE_JSON")
    fi
  done
  
  # JetBrains IDEs (IntelliJ, PyCharm, WebStorm, etc.)
  JETBRAINS_DIRS=(
    "$HOME/.config/JetBrains"
    "$HOME/.var/app/com.jetbrains.*/data/JetBrains"
  )
  
  for jetbrains_base in "''${JETBRAINS_DIRS[@]}"; do
    if [ -d "$jetbrains_base" ]; then
      # Find all JetBrains IDE installations
      while IFS= read -r ide_dir; do
        if [ -d "$ide_dir" ]; then
          IDE_NAME=$(basename "$ide_dir")
          
          # Scan plugins
          PLUGINS="[]"
          if [ -d "$ide_dir/config/plugins" ]; then
            while IFS= read -r plugin_dir; do
              if [ -d "$plugin_dir" ] && [ -f "$plugin_dir/META-INF/plugin.xml" ]; then
                PLUGIN_ID=$(basename "$plugin_dir")
                PLUGIN_NAME=$(grep -oP '<name>\K[^<]+' "$plugin_dir/META-INF/plugin.xml" 2>/dev/null | head -1 || echo "Unknown")
                PLUGIN_VERSION=$(grep -oP '<version>\K[^<]+' "$plugin_dir/META-INF/plugin.xml" 2>/dev/null | head -1 || echo "Unknown")
                
                PLUGIN_JSON=$(${pkgs.jq}/bin/jq -n \
                  --arg id "$PLUGIN_ID" \
                  --arg name "$PLUGIN_NAME" \
                  --arg version "$PLUGIN_VERSION" \
                  '{
                    id: $id,
                    name: $name,
                    version: $version
                  }')
                
                PLUGINS=$(${pkgs.jq}/bin/jq --argjson plugin "$PLUGIN_JSON" '. + [$plugin]' <<< "$PLUGINS")
              fi
            done < <(find "$ide_dir/config/plugins" -maxdepth 1 -type d 2>/dev/null | head -100 || true)
          fi
          
          # Settings
          SETTINGS="{}"
          if [ -d "$ide_dir/config" ]; then
            SETTINGS=$(${pkgs.jq}/bin/jq -n \
              --arg configDir "$ide_dir/config" \
              '{
                configDir: $configDir,
                note: "Settings directory exists"
              }')
          fi
          
          IDE_JSON=$(${pkgs.jq}/bin/jq -n \
            --arg name "$IDE_NAME" \
            --arg path "$ide_dir" \
            --argjson plugins "$PLUGINS" \
            --argjson settings "$SETTINGS" \
            '{
              ide: $name,
              path: $path,
              plugins: {
                count: ($plugins | length),
                items: $plugins
              },
              settings: $settings
            }')
          
          IDES+=("$IDE_JSON")
        fi
      done < <(find "$jetbrains_base" -maxdepth 1 -type d ! -name "JetBrains" 2>/dev/null | head -20 || true)
    fi
  done
  
  # Neovim / Vim
  if [ -d "$HOME/.config/nvim" ] || [ -d "$HOME/.vim" ]; then
    # Check for plugin managers
    PLUGINS="[]"
    
    # vim-plug
    if [ -f "$HOME/.config/nvim/init.vim" ] || [ -f "$HOME/.vimrc" ]; then
      VIMRC="$HOME/.config/nvim/init.vim"
      [ ! -f "$VIMRC" ] && VIMRC="$HOME/.vimrc"
      
      if [ -f "$VIMRC" ]; then
        # Extract plugin URLs from vim-plug format
        while IFS= read -r plugin_line; do
          if [[ "$plugin_line" =~ Plug\s+['"'"'"]?([^'"'"'"]+)['"'"'"]? ]]; then
            PLUGIN_URL="''${BASH_REMATCH[1]}"
            PLUGIN_NAME=$(basename "$PLUGIN_URL" .git)
            
            PLUGIN_JSON=$(${pkgs.jq}/bin/jq -n \
              --arg name "$PLUGIN_NAME" \
              --arg url "$PLUGIN_URL" \
              '{
                name: $name,
                url: $url,
                manager: "vim-plug"
              }')
            
            PLUGINS=$(${pkgs.jq}/bin/jq --argjson plugin "$PLUGIN_JSON" '. + [$plugin]' <<< "$PLUGINS")
          fi
        done < "$VIMRC"
      fi
    fi
    
    # packer.nvim
    if [ -d "$HOME/.local/share/nvim/site/pack/packer" ]; then
      while IFS= read -r plugin_dir; do
        if [ -d "$plugin_dir" ]; then
          PLUGIN_NAME=$(basename "$plugin_dir")
          PLUGIN_JSON=$(${pkgs.jq}/bin/jq -n \
            --arg name "$PLUGIN_NAME" \
            '{
              name: $name,
              manager: "packer"
            }')
          
          PLUGINS=$(${pkgs.jq}/bin/jq --argjson plugin "$PLUGIN_JSON" '. + [$plugin]' <<< "$PLUGINS")
        fi
      done < <(find "$HOME/.local/share/nvim/site/pack/packer" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | head -50 || true)
    fi
    
    if [ "$(${pkgs.jq}/bin/jq 'length' <<< "$PLUGINS")" -gt 0 ]; then
      IDE_JSON=$(${pkgs.jq}/bin/jq -n \
        --arg name "Neovim/Vim" \
        --argjson plugins "$PLUGINS" \
        '{
          ide: $name,
          plugins: {
            count: ($plugins | length),
            items: $plugins
          }
        }')
      
      IDES+=("$IDE_JSON")
    fi
  fi
  
  # Combine all IDEs
  IDES_JSON="[]"
  for ide in "''${IDES[@]}"; do
    IDES_JSON=$(${pkgs.jq}/bin/jq --argjson ide "$ide" '. + [$ide]' <<< "$IDES_JSON")
  done
  
  # Output JSON
  ${pkgs.jq}/bin/jq -n \
    --argjson ides "$IDES_JSON" \
    '{
      ides: {
        count: ($ides | length),
        items: $ides
      }
    }' > "$OUTPUT_FILE"
  
  IDE_COUNT=$(${pkgs.jq}/bin/jq '.ides.count' "$OUTPUT_FILE")
  TOTAL_PLUGINS=$(${pkgs.jq}/bin/jq '[.ides.items[] | .extensions.count // .plugins.count // 0] | add' "$OUTPUT_FILE")
  echo "✅ Found $IDE_COUNT IDE(s) with $TOTAL_PLUGINS total extensions/plugins"
''

