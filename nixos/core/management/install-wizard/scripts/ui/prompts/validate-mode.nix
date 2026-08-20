# Migrated from ui/prompts/validate-mode.sh — body via fromJSON (Nix-safe).
{ pkgs, getModuleApi ? null, ... }:
pkgs.writeText "validate-mode.sh" (builtins.fromJSON ''
"#!/usr/bin/env bash\n\nvalidate_selection() {\n    local selections=(\"\u0024@\")\n    \n    # Check if selections are empty\n    if [ \u0024{#selections[@]} -eq 0 ]; then\n        echo \"No selections made.\"\n        return 1\n    fi\n\n    # Check for feature conflicts\n    # Docker conflicts\n    if [[ \" \u0024{selections[@]} \" =~ \" docker \" && \" \u0024{selections[@]} \" =~ \" podman \" ]]; then\n        echo \"Error: 'docker' and 'podman' cannot be selected together.\"\n        return 1\n    fi\n\n    return 0\n}\n\nexport -f validate_selection\n"
'')
