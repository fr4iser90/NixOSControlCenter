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

  echo "Debug: Updated content:"
  echo "----------------------"
  cat "$entry_file"
  echo "----------------------"

  # Clean up
  rm -f "$entry_file.tmp" "$entry_file.backup"

  echo "Successfully updated boot entry for generation $gen_number:"
  echo "  - Title: $new_name $([ -n "$nixos_version" ] && echo "($nixos_version)")"
}

# Main logic with input validation
if [ $# -eq 0 ]; then
  latest_gen=$(find_latest_generation)
  if [ "$latest_gen" -gt 0 ]; then
    rename_entry "$latest_gen" "${HOSTNAME}Setup"
  else
    echo "Error: No generations found"
    exit 1
  fi
elif [ $# -eq 2 ]; then
  rename_entry "$1" "$2"
else
  echo "Usage: rename-boot-entries [generation-number new-name]"
  exit 1
fi
