#!/usr/bin/env bash
# Fail if NixOS Control Center modules hardcode discovery paths.
# Modules must use getModuleConfig / getModuleApi / metadata.configPath.
# Peer NixOS attrs: (getModuleApi "<name>").fromConfig config — never getModuleNixConfig.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
NIXOS="${ROOT}/nixos"
FAIL=0
HITS=0

# Paths that are allowed to mention dotted config paths (bootstrap / docs / templates).
# Everything else under nixos/core and nixos/modules is scanned.
is_allowlisted() {
  local f="$1"
  case "$f" in
    */doc/*|*/docs/*|*/plans/*|*/knowledge/*|*/CHANGELOG*|*/ROADMAP*|*/README*)
      return 0 ;;
    */template-config.nix|*/template-per-user-config.nix)
      return 0 ;;
    */module-manager/lib/discovery.nix|*/module-manager/lib/module-config.nix|*/module-manager/lib/config-helpers.nix)
      return 0 ;;
    */system-manager/lib/config-loader.nix|*/system-manager/lib/config-layout.nix|*/system-manager/lib/config-paths.nix)
      return 0 ;;
    */system-manager/lib/layout-convert.nix|*/system-manager/lib/config-facade.nix)
      return 0 ;;
    */flake.nix)
      # flake bootstrap reads system-manager channel before modules evaluate
      return 0 ;;
    */disabled-hint.nix)
      # user-facing hint text may show example systemConfig path
      return 0 ;;
    */options.nix)
      # may document example paths in descriptions
      return 0 ;;
  esac
  return 1
}

scan() {
  local pattern="$1"
  local label="$2"
  local file
  while IFS= read -r -d '' file; do
    is_allowlisted "$file" && continue
    if rg -n --glob '*.nix' -e "$pattern" "$file" >/tmp/ncc-hardcode-hits.txt 2>/dev/null; then
      echo "FAIL [$label]: $file"
      cat /tmp/ncc-hardcode-hits.txt
      echo
      FAIL=1
      HITS=$((HITS + $(wc -l </tmp/ncc-hardcode-hits.txt)))
    fi
  done < <(find "$NIXOS/core" "$NIXOS/modules" -type f -name '*.nix' -print0 2>/dev/null)
}

echo "=== NCC: validate no hardcoded module paths ==="
echo "root: $NIXOS"

# Removed helper — must never appear
scan 'getModuleNixConfig' \
  'banned getModuleNixConfig (use (getModuleApi \"…\").fromConfig config)'

# Hardcoded NixOS config trees (must use getModuleApi.fromConfig / metadata.configPath)
scan 'config\.core\.(management|base)\.[a-zA-Z0-9_-]+' \
  'config.core.<path> hardcode'

# Hardcoded systemConfig dotted paths in attrByPath / literal access
scan 'attrByPath\s*\[\s*"core"' \
  'attrByPath [\"core\"…] hardcode'

scan 'systemConfig\.core\.(management|base)\.[a-zA-Z0-9_-]+' \
  'systemConfig.core.<path> hardcode'

# Soft optional wiring for module helpers (forbidden)
scan 'getModule(Api|Config|Metadata)\s*\?\s*null' \
  'getModule* ? null'

scan 'metadata\s*\?\s*null' \
  'metadata ? null (pass metadata explicitly)'

scan 'moduleName\s*\?\s*"' \
  'moduleName ? \"…\"'

# Relative imports that jump into another top-level module tree
scan 'import\s+\.\./(\.\./)+(modules|core)/' \
  'relative cross-module import'

if [[ "$FAIL" -ne 0 ]]; then
  echo "=== FAILED: $HITS hardcoded-path hit(s) ==="
  echo "Use getModuleConfig / getModuleApi / metadata.configPath."
  echo "Peer NixOS attrs: (getModuleApi \"…\").fromConfig config"
  echo "See .cursor/rules/ncc-module-discovery.mdc and docs/AI/RULES.md"
  exit 1
fi

echo "=== OK: no forbidden hardcoded module paths ==="
exit 0
