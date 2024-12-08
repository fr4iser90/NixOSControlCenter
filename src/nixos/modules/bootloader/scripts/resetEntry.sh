if [ $# -ne 1 ]; then
  echo "Usage: reset-boot-entry generation-number"
  exit 1
fi

# Validate input
if ! validate_generation "$1"; then
  exit 1
fi

entry_file="/boot/loader/entries/nixos-generation-$1.conf"

# Security checks
if [ ! -f "$entry_file" ] || [ -h "$entry_file" ]; then
  echo "Error: Invalid boot entry file: $entry_file"
  exit 1
fi

# Create backup
cp "$entry_file" "$entry_file.backup"

# Perform reset with error checking
if ! sed -i.tmp "s/^title.*/title NixOS/" "$entry_file"; then
  echo "Error: Failed to reset title"
  mv "$entry_file.backup" "$entry_file"
  exit 1
fi

if ! sed -i.tmp "s/^sort-key.*/sort-key nixos/" "$entry_file"; then
  echo "Error: Failed to reset sort-key"
  mv "$entry_file.backup" "$entry_file"
  exit 1
fi

# Clean up
rm -f "$entry_file.tmp" "$entry_file.backup"

echo "Successfully reset boot entry for generation $1"
