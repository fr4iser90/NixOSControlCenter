# Migrated from checks/modules/run-all.sh — body via fromJSON (Nix-safe).
{ pkgs }:
pkgs.writeText "run-all.sh" (builtins.fromJSON ''
"#!/usr/bin/env bash\n# Module static validation suite\nset -euo pipefail\nDIR=\"\u0024(cd \"\u0024(dirname \"\u0024{BASH_SOURCE[0]}\")\" && pwd)\"\necho \">>> validate-no-hardcoded-paths.sh\"\nbash \"\u0024DIR/validate-no-hardcoded-paths.sh\"\necho\necho \">>> validate-module-imports.sh\"\nbash \"\u0024DIR/validate-module-imports.sh\"\necho \"All module checks passed.\"\n"
'')
