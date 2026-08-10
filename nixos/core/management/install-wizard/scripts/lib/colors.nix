# Migrated from lib/colors.sh — body via fromJSON (Nix-safe).
{ pkgs }:
pkgs.writeText "colors.sh" (builtins.fromJSON ''
"#!/usr/bin/env bash\n\n# Terminal Colors\nexport RED='\\033[0;31m'\nexport GREEN='\\033[0;32m'\nexport YELLOW='\\033[1;33m'\nexport BLUE='\\033[0;34m'\nexport PURPLE='\\033[0;35m'\nexport CYAN='\\033[0;36m'\nexport GRAY='\\033[0;37m'\nexport NC='\\033[0m'\n\n# Mark as imported\nexport COLORS_IMPORTED=1"
'')
