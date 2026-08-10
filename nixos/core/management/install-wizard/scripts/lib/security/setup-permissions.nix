# Migrated from lib/security/setup-permissions.sh — body via fromJSON (Nix-safe).
{ pkgs }:
pkgs.writeText "setup-permissions.sh" (builtins.fromJSON ''
"#!/usr/bin/env bash\n\nsetup_permissions() {\n    log_section \"Setting up script permissions\"\n    \n    # Setze Berechtigungen f\u00fcr alle .sh Dateien\n    if ! find \"\u0024SCRIPT_ROOT\" -type f -name \"*.sh\" -exec chmod +x {} \\; ; then\n        log_error \"Failed to set execute permissions\"\n        return 1\n    fi\n    \n    log_success \"Execute permissions set for all shell scripts \u2713\"\n    return 0\n}\n\n# Export function\nexport -f setup_permissions\n\n# Check script execution\ncheck_script_execution \"SCRIPT_ROOT\" \"setup_permissions\""
'')
