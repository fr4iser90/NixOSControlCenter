# Migrated from ui/prompts/common.sh — body via fromJSON (Nix-safe).
{ pkgs }:
pkgs.writeText "common.sh" (builtins.fromJSON ''
"#!/usr/bin/env bash\n\n# FZF base styling\nFZF_DEFAULT_OPTS=\"\n    --height=40% \n    --border=rounded \n    --preview-window=bottom:3:wrap\n    --header-first\n\"\n\n# Gemeinsame Funktionen f\u00fcr Modul-Auswahl\nselect_modules() {\n    local title=\"\u00241\"\n    shift\n    local -n modules=\"\u00241\"  # Nameref auf das Modul-Array\n    \n    printf \"%s\\n\" \"\u0024{!modules[@]}\" | fzf \\\n        --header=\"\u0024title\" \\\n        --preview=\"echo '\u0024{modules[{}]}'\" \\\n        --multi \\\n        --prompt=\"Modules > \"\n}"
'')
