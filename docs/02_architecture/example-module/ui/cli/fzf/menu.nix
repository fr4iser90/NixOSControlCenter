# fzf Menu-Definition
# Purpose: fzf-basierte Menus (aus Scripts extrahiert!)
# Scripts bleiben clean, UI-Logik hier

{ lib, pkgs, cfg, ... }:

let
  # Menu Items Definition
  menuItems = [
    { name = "📋 List Items"; action = "list"; description = "List all items"; }
    { name = "➕ Add Item"; action = "add"; description = "Add new item"; }
    { name = "🔍 Search"; action = "search"; description = "Search items"; }
    { name = "⚙️ Settings"; action = "settings"; description = "Module settings"; }
    { name = "❌ Quit"; action = "quit"; description = "Exit menu"; }
  ];
  
  # fzf Menu Script
  fzfMenu = pkgs.writeShellScriptBin "ncc-example-fzf" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Menu Items
    ITEMS=(
      "📋 List Items|list|List all items"
      "➕ Add Item|add|Add new item"
      "🔍 Search|search|Search items"
      "⚙️ Settings|settings|Module settings"
      "❌ Quit|quit|Exit menu"
    )
    
    # Display menu with fzf
    SELECTION=$(printf '%s\n' "''${ITEMS[@]}" | ${pkgs.fzf}/bin/fzf \
      --prompt="Example Module > " \
      --header="Select an action:" \
      --preview="echo {2}" \
      --preview-window=right:30% \
      --delimiter="|" \
      --with-nth=1,3)
    
    if [ -z "$SELECTION" ]; then
      exit 0
    fi
    
    # Extract action
    ACTION=$(echo "$SELECTION" | cut -d'|' -f2)
    
    # Execute action
    case "$ACTION" in
      list)
        ncc example-module list
        ;;
      add)
        ncc example-module add
        ;;
      search)
        ncc example-module search
        ;;
      settings)
        ncc example-module settings
        ;;
      quit)
        exit 0
        ;;
      *)
        echo "Unknown action: $ACTION"
        exit 1
        ;;
    esac
  '';
in
  fzfMenu
