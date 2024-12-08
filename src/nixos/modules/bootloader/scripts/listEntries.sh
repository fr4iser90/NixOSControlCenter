echo "Available Boot Entries:"
for entry in /boot/loader/entries/nixos-generation-*.conf; do
  if [ -f "$entry" ] && [ ! -h "$entry" ]; then
    gen_number=$(basename "$entry" | grep -o '[0-9]\+')
    echo "Generation $gen_number:"
    echo "File: $entry"
    echo "Content:"
    cat "$entry"
    echo "----------------------"
  fi
done
