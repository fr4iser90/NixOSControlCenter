#!/usr/bin/env bash
# Blueprint users must land in staged systemConfig (monolith core.base.user).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
STAGING="$(mktemp -d /tmp/ncc-users-staging.XXXXXX)"
BP="$ROOT/nixos/core/management/install-wizard/scripts/setup/modes/host-blueprints/fr4iser-jetson-orin"

export SYSTEM_CONFIG_DIR="$STAGING"
export MONOLITH_FILE="$STAGING/systemConfig.nix"
export NIXOS_ROOT="$STAGING"
export CONFIGS_BASE="$STAGING"
export NIXOS_CONFIG_DIR="$ROOT/nixos"
export SERIALIZE_NIX="$ROOT/nixos/core/management/system-manager/lib/serialize-json-to-nix.nix"

FACADE=$(nix-build -E "with import <nixpkgs> {}; (import $ROOT/nixos/core/management/install-wizard/scripts/setup/config/config-facade.nix { inherit pkgs; getModuleMetadata = name: { path = \"$ROOT/nixos/core/management/system-manager\"; }; })" 2>/dev/null | head -1)
WRITER=$(nix-build -E "with import <nixpkgs> {}; callPackage $ROOT/nixos/core/management/install-wizard/scripts/setup/config/config-writer.nix {}" 2>/dev/null | head -1)
TEMPLATE=$(nix-build -E "with import <nixpkgs> {}; callPackage $ROOT/nixos/core/management/install-wizard/scripts/setup/config/apply-install-template.nix {}" 2>/dev/null | head -1)

log_section() { echo "=== $* ==="; }
log_info() { echo "[INFO] $*"; }
log_success() { echo "[ OK ] $*"; }
log_error() { echo "[FAIL] $*" >&2; }
log_warn() { echo "[WARN] $*"; }
log_debug() { :; }
backup_file() { return 0; }
export -f log_section log_info log_success log_error log_warn log_debug backup_file

# shellcheck source=/dev/null
source "$FACADE"
# shellcheck source=/dev/null
source "$WRITER"
# shellcheck source=/dev/null
source "$TEMPLATE"

apply_install_template "$BP"

if ! grep -q 'fr4iser' "$STAGING/systemConfig.nix"; then
  echo "FAIL: no user fr4iser in $STAGING/systemConfig.nix"
  head -40 "$STAGING/systemConfig.nix"
  rm -rf "$STAGING"
  exit 1
fi
if ! grep -q 'role = "admin"' "$STAGING/systemConfig.nix"; then
  echo "FAIL: no admin role in staged systemConfig"
  rm -rf "$STAGING"
  exit 1
fi

echo "OK: blueprint users staged under core.base.user"
rm -rf "$STAGING"
