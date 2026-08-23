# Install-wizard test: validate-bash-embedding.sh (Nix-safe fromJSON body).
{ pkgs }:
pkgs.writeText "validate-bash-embedding.sh" (builtins.fromJSON ''
"#!/usr/bin/env bash\n# Catch bash \\\u0024{VAR:-} in Nix '' strings (use ''\\\u0024{ for shell).\nset -euo pipefail\nDIR=\"\u0024(cd \"\u0024(dirname \"\u0024{BASH_SOURCE[0]}\")\" && pwd)\"\nROOT=\"\u0024(cd \"\u0024DIR/../..\" && pwd)\"\nexec bash \"\u0024ROOT/tests/install-wizard/validate-bash-embedding.sh\"\n"
'')
