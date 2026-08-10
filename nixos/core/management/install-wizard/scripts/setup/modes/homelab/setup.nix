# Migrated from setup/modes/homelab/setup.sh — body via fromJSON (Nix-safe).
{ pkgs }:
pkgs.writeText "setup.sh" (builtins.fromJSON ''
"#!/usr/bin/env bash\n\nsetup_homelab() {\n    log_section \"Homelab Setup\"\n    \n    # 1. User Setup (macht bereits alles was wir brauchen)\n    setup_homelab_config || return 1\n    \n    # 2. Deploy Config\n    deploy_config\n\n    return 0\n}\n\nexport -f setup_homelab"
'')
