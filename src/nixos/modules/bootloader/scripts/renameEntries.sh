find_latest_generation() {
  local latest=0
  for entry in /boot/loader/entries/nixos-generation-*.conf; do
    if [ -f "$entry" ]; then
      local num=$(basename "$entry" | grep -o '[0-9]\+')
      if [ "$num" -gt "$latest" ]; then
        latest=$num
      fi
    fi
  done
  echo "$latest"
}

count_setup_generations() {
  local sort_key=$1
  find /boot/loader/entries -name 'nixos-generation-*.conf' -exec grep -l "^sort-key $sort_key" {} \; | wc -l
}

update_entries_file() {
  local gen_number=$1
  local title=$2
  local sort_key=$3

  # Erstelle/Update Entry in JSON
  local json_entry=$(jq --arg gen "$gen_number" \
                       --arg title "$title" \
                       --arg sort "$sort_key" \
                       --arg time "$(date -Iseconds)" \
                       '.generations[$gen] = {
                         "title": $title,
                         "sortKey": $sort,
                         "lastUpdate": $time
                       }' "$ENTRIES_FILE")

  echo "$json_entry" > "$ENTRIES_FILE"
}

get_entry_from_file() {
  local gen_number=$1
  jq -r --arg gen "$gen_number" '.generations[$gen] // empty' "$ENTRIES_FILE"
}

print_setup_summary() {
  local setup_name=$1
  local sort_key=$2
  local limit=$3

  echo ""
  echo "Boot Entry Setup Summary"
  echo "========================"
  echo "Setup: $setup_name"
  echo "Sort Key: $sort_key"

  # Zähle aktuelle Generationen
  local count=$(find /boot/loader/entries -name 'nixos-generation-*.conf' -exec grep -l "^sort-key $sort_key" {} \; | wc -l)
  echo "Generations: $count/$limit"

  echo ""
  echo "Current Generations:"
  echo "-------------------"
  for entry in $(find /boot/loader/entries -name 'nixos-generation-*.conf' -exec grep -l "^sort-key $sort_key" {} \; | sort -V); do
    local gen=$(basename "$entry" | grep -o '[0-9]\+')
    local title=$(grep "^title" "$entry" | sed 's/^title //')
    local version=$(grep "^version" "$entry" | grep -o "Generation [0-9]\+.*")
    echo "Gen $gen: $title ($version)"
  done

  # Warnung wenn Limit fast erreicht
  if [ "$count" -ge "$((limit - 2))" ]; then
    echo ""
    echo "WARNING: Approaching generation limit ($count/$limit)"
    echo "Consider cleaning up old generations!"
  fi
}

rename_entry() {
  local gen_number=$1
  local new_name=$2
  local entry_file="/boot/loader/entries/nixos-generation-$gen_number.conf"

  echo "Debug: Processing entry file: $entry_file"
  echo "Debug: Current content:"
  echo "----------------------"
  cat "$entry_file"
  echo "----------------------"

  # Validate inputs
  if ! validate_generation "$gen_number"; then
    echo "Debug: Generation validation failed"
    exit 1
  fi

  if ! validate_name "$new_name"; then
    echo "Debug: Name validation failed"
    exit 1
  fi

  # Check if file exists and is a regular file
  if [ ! -f "$entry_file" ] || [ -h "$entry_file" ]; then
    echo "Error: Invalid boot entry file: $entry_file"
    exit 1
  fi

  # Prüfe Setup-Limit
  local current_count=$(count_setup_generations "$SORT_KEY")
  if [ "$current_count" -ge "$SETUP_LIMIT" ]; then
    echo "Warning: Reached generation limit for $new_name ($SETUP_LIMIT)"
  fi

  echo "Debug: Reading version line"
  # Extract version from version line first
  local version_line=$(grep "^version" "$entry_file" || echo "")
  local nixos_version=""

  echo "Debug: Version line: $version_line"

  # Try to extract version from different formats
  if echo "$version_line" | grep -q "[0-9]\+\.[0-9]\+\.[0-9]\+"; then
    nixos_version=$(echo "$version_line" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" || echo "")
    echo "Debug: Found version in version line: $nixos_version"
  else
    echo "Debug: Trying options line"
    # Try to extract from options line as fallback
    local options_line=$(grep "^options" "$entry_file" || echo "")
    echo "Debug: Options line: $options_line"
    if echo "$options_line" | grep -q "[0-9]\+\.[0-9]\+\.[0-9]\+"; then
      nixos_version=$(echo "$options_line" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" || echo "")
      echo "Debug: Found version in options line: $nixos_version"
    fi
  fi

  # Create backup
  cp "$entry_file" "$entry_file.backup"

  echo "Debug: Updating title. Version: '$nixos_version'"
  # Update title with version if available
  if [ -n "$nixos_version" ]; then
    echo "Debug: Setting title with version"
    if ! sed -i.tmp "s/^title.*/title $new_name ($nixos_version)/" "$entry_file"; then
      echo "Error: Failed to update title"
      mv "$entry_file.backup" "$entry_file"
      exit 1
    fi
  else
    echo "Debug: Setting title without version"
    if ! sed -i.tmp "s/^title.*/title $new_name/" "$entry_file"; then
      echo "Error: Failed to update title"
      mv "$entry_file.backup" "$entry_file"
      exit 1
    fi
  fi

  # Update sort-key für Gruppierung
  if ! sed -i.tmp "s/^sort-key.*/sort-key $SORT_KEY/" "$entry_file"; then
    echo "Error: Failed to update sort-key"
    mv "$entry_file.backup" "$entry_file"
    exit 1
  fi

  echo "Debug: Updated content:"
  echo "----------------------"
  cat "$entry_file"
  echo "----------------------"

  # Clean up
  rm -f "$entry_file.tmp" "$entry_file.backup"

  # Update JSON-Datei
  update_entries_file "$gen_number" "$new_name" "$SORT_KEY"

  echo "Successfully updated boot entry for generation $gen_number:"
  echo "  - Title: $new_name $([ -n "$nixos_version" ] && echo "($nixos_version)")"
  echo "  - Sort Key: $SORT_KEY"

  # Zeige Zusammenfassung
  print_setup_summary "$SETUP_NAME" "$SORT_KEY" "$SETUP_LIMIT"
}

update_all_entries() {
  echo "Updating all boot entries..."
  
  # Finde alle Generationen
  for entry in /boot/loader/entries/nixos-generation-*.conf; do
    if [ -f "$entry" ] && [ ! -h "$entry" ]; then
      local gen_number=$(basename "$entry" | grep -o '[0-9]\+')
      
      # Prüfe ob die Generation bereits im korrekten Format ist
      if ! grep -q "^sort-key $SORT_KEY" "$entry"; then
        echo "Updating generation $gen_number..."
        rename_entry "$gen_number" "$SETUP_NAME"
      else
        echo "Generation $gen_number already updated"
      fi
    fi
  done
  
  # Zeige Zusammenfassung
  print_setup_summary "$SETUP_NAME" "$SORT_KEY" "$SETUP_LIMIT"
}

# Hauptlogik
if [ $# -eq 0 ]; then
  # Aktualisiere alle existierenden Einträge (inkl. der neuesten)
  update_all_entries
elif [ $# -eq 2 ]; then
  rename_entry "$1" "$2"
else
  echo "Usage: rename-boot-entries [generation-number new-name]"
  exit 1
fi
