#!/usr/bin/env bash

list_entries() {
  jq -r '.generations | to_entries[] | "Generation \(.key):\n  Title: \(.value.title)\n  Sort Key: \(.value.sortKey)\n  Last Update: \(.value.lastUpdate)\n  Locked: \(.value.locked // false)\n"' "$ENTRIES_FILE"
}

lock_entry() {
  local gen=$1
  jq --arg gen "$gen" '.generations[$gen].locked = true' "$ENTRIES_FILE" > "$ENTRIES_FILE.tmp" \
    && mv "$ENTRIES_FILE.tmp" "$ENTRIES_FILE"
  echo "Locked entry for generation $gen"
}

unlock_entry() {
  local gen=$1
  jq --arg gen "$gen" '.generations[$gen].locked = false' "$ENTRIES_FILE" > "$ENTRIES_FILE.tmp" \
    && mv "$ENTRIES_FILE.tmp" "$ENTRIES_FILE"
  echo "Unlocked entry for generation $gen"
}

case "$1" in
  "list") list_entries ;;
  "lock") lock_entry "$2" ;;
  "unlock") unlock_entry "$2" ;;
  *)
    echo "Usage: manage-entries <command> [args]"
    echo "Commands:"
    echo "  list           List all entries"
    echo "  lock <gen>     Lock entry for generation"
    echo "  unlock <gen>   Unlock entry for generation"
    ;;
esac