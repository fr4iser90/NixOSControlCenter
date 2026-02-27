{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";
  actions = import ../actions.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

in
pkgs.writeScriptBin "module-manager-tui" ''
  #!${pkgs.bash}/bin/bash

  # Add gum to PATH
  export PATH="${pkgs.gum}/bin:$PATH"
  #!${pkgs.bash}/bin/bash

  # Module Manager TUI - 5-Panel Design with Gum
  # Implements design.md specifications using tui-engine actions

  set -euo pipefail

  # Starting message
  echo "📦 Module Manager TUI Starting"

  # Global state
  cursor_pos=0
  search_term=""
  filter_status="all"
  filter_category="all"

  # Load modules
  echo "ℹ Loading modules..."
  modules=$(${actions.getModuleList})

  if [[ -z "$modules" ]]; then
      echo "✗ No modules found!"
      exit 1
  fi

  count=$(echo "$modules" | wc -l)
  echo "✓ Loaded $count modules"

  # Interactive Gum main function - RICHTIG INTERAKTIV!
  main() {
      while true; do
          clear

          # Header
          total_count=$(echo "$modules" | wc -l)
          enabled_count=$(echo "$modules" | grep "|enabled|" | wc -l)
          gum style --bold --foreground 39 "📦 Module Manager | $total_count modules | $enabled_count enabled"

          echo

          # INTERAKTIVE MENÜ-AUSWAHL mit Gum!
          choice=$(gum choose \
              "📋 List All Modules" \
              "🔍 Search Modules" \
              "⚡ Enable Module" \
              "❌ Disable Module" \
              "ℹ️ Show Module Details" \
              "🔄 Refresh" \
              "👋 Quit")

          case "$choice" in
              "📋 List All Modules")
                  # INTERAKTIVE MODUL-LISTE
                  module_names=$(echo "$modules" | cut -d'|' -f2)
                  selected=$(echo "$module_names" | gum choose --header "Select a module to view")
                  echo "📋 Selected: $selected"
                  gum input --placeholder "Press Enter to continue..."
                  ;;

              "🔍 Search Modules")
                  # INTERAKTIVE SUCHE
                  search_term=$(gum input --placeholder "Search for modules...")
                  results=$(echo "$modules" | grep -i "$search_term" | cut -d'|' -f2)
                  if [[ -n "$results" ]]; then
                      selected=$(echo "$results" | gum choose --header "Search results for '$search_term'")
                      echo "🔍 Found: $selected"
                  else
                      echo "❌ No modules found matching '$search_term'"
                  fi
                  gum input --placeholder "Press Enter to continue..."
                  ;;

              "⚡ Enable Module")
                  # INTERAKTIVE MODUL-AKTIVIERUNG
                  module_names=$(echo "$modules" | cut -d'|' -f2)
                  to_enable=$(echo "$module_names" | gum choose --header "Select module to ENABLE")

                  if gum confirm "Enable $to_enable?"; then
                      ${actions.toggle_module_script}/bin/toggle-module "$to_enable" "true"
                      echo "✅ $to_enable enabled successfully!"
                      # Refresh modules
                      modules=$(${actions.getModuleList})
                  else
                      echo "❌ Enable cancelled"
                  fi
                  gum input --placeholder "Press Enter to continue..."
                  ;;

              "❌ Disable Module")
                  # INTERAKTIVE MODUL-DEAKTIVIERUNG
                  module_names=$(echo "$modules" | cut -d'|' -f2)
                  to_disable=$(echo "$module_names" | gum choose --header "Select module to DISABLE")

                  if gum confirm "Disable $to_disable?"; then
                      ${actions.toggle_module_script}/bin/toggle-module "$to_disable" "false"
                      echo "❌ $to_disable disabled successfully!"
                      # Refresh modules
                      modules=$(${actions.getModuleList})
                  else
                      echo "❌ Disable cancelled"
                  fi
                  gum input --placeholder "Press Enter to continue..."
                  ;;

              "ℹ️ Show Module Details")
                  # INTERAKTIVE DETAIL-ANZEIGE
                  module_names=$(echo "$modules" | cut -d'|' -f2)
                  selected=$(echo "$module_names" | gum choose --header "Select module for details")

                  # Get full module data
                  module_data=$(echo "$modules" | grep "|$selected|" | head -1)
                  IFS='|' read -r id name desc category status version path <<< "$module_data"

                  # RICHTIG STYLED DETAILS mit Gum!
                  gum style \
                      --border double \
                      --border-foreground 39 \
                      --padding "1 2" \
                      --margin "1 0" \
                      "📦 Module Details

📛 Name: $name
📊 Status: $status
🏷️ Category: $category
📄 Description: $desc
🗂️ Path: $path

Press Enter to continue..."

                  read -r
                  ;;

              "🔄 Refresh")
                  echo "🔄 Refreshing modules..."
                  modules=$(${actions.getModuleList})
                  echo "✅ Modules refreshed!"
                  gum input --placeholder "Press Enter to continue..."
                  ;;

              "👋 Quit")
                  gum style --bold --foreground 39 "👋 Goodbye!"
                  exit 0
                  ;;
          esac
      done
  }

  # Run main
  echo "Starting main function..."
  main
''
