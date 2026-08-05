#!/usr/bin/env bash
# Unit tests for packages/lib/docker-mode.nix (smart rootless/root).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MODE_NIX="$ROOT/nixos/core/base/packages/lib/docker-mode.nix"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $*"; }

eval_mode() {
  local expr="$1"
  nix-instantiate --eval --strict -E "$expr" 2>/dev/null | tr -d '"'
}

assert_mode() {
  local label="$1" expr="$2" want="$3"
  local got
  got=$(eval_mode "$expr")
  if [[ "$got" == "$want" ]]; then
    pass "$label → $want"
  else
    fail "$label (got='$got' want='$want')"
  fi
}

DM="(import $MODE_NIX)"

echo "== docker-mode.nix =="

assert_mode "no docker" \
  "$DM { packageModules = []; }" \
  "null"

assert_mode "desktop docker → rootless" \
  "$DM { packageModules = [ \"docker\" ]; }" \
  "rootless"

assert_mode "explicit docker-rootless → rootless" \
  "$DM { packageModules = [ \"docker-rootless\" ]; }" \
  "rootless"

assert_mode "force root" \
  "$DM { packageModules = [ \"docker\" ]; dockerRoot = true; }" \
  "root"

assert_mode "force rootless even with swarm" \
  "$DM {
    packageModules = [ \"docker\" ];
    dockerRoot = false;
    systemConfig = {
      modules.infrastructure.homelab-manager.swarm = \"manager\";
    };
  }" \
  "rootless"

assert_mode "swarm option → root" \
  "$DM {
    packageModules = [ \"docker\" ];
    systemConfig = {
      modules.infrastructure.homelab-manager.swarm = \"manager\";
    };
  }" \
  "root"

assert_mode "swarm nested writer shape → root" \
  "$DM {
    packageModules = [ \"docker\" ];
    systemConfig = {
      modules.infrastructure.homelab-manager.homelab = {
        type = \"swarm\";
        role = \"worker\";
      };
    };
  }" \
  "root"

assert_mode "ai-workspace enable → root" \
  "$DM {
    packageModules = [ \"docker\" ];
    systemConfig = {
      modules.specialized.ai-workspace.enable = true;
    };
  }" \
  "root"

assert_mode "features.ai-workspace → root" \
  "$DM {
    packageModules = [ \"docker\" ];
    systemConfig = { features.ai-workspace = true; };
  }" \
  "root"

assert_mode "homelab single (no swarm) → rootless" \
  "$DM {
    packageModules = [ \"docker\" ];
    systemConfig = {
      modules.infrastructure.homelab-manager = {
        enable = true;
        swarm = null;
        homelab.type = \"single\";
      };
    };
  }" \
  "rootless"

assert_mode "docker.enable without modules → rootless" \
  "$DM { dockerEnable = true; }" \
  "rootless"

echo
echo "========================================"
echo "docker-mode: $PASS passed, $FAIL failed"
echo "========================================"
[[ $FAIL -eq 0 ]]
