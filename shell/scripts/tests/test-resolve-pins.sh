#!/usr/bin/env bash
# Unit tests for desktop/lib/resolve-pins.nix (taskbar pin derivation).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PIN_MAP="$ROOT/nixos/core/base/desktop/lib/pin-map.nix"
RESOLVE="$ROOT/nixos/core/base/desktop/lib/resolve-pins.nix"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $*"; }

# Normalize nix list output: [ "a" "b" ] → a b
eval_pins() {
  local expr="$1"
  nix-instantiate --eval --strict -E "$expr" 2>/dev/null \
    | tr -d '[]"' \
    | xargs echo
}

assert_pins() {
  local label="$1" expr="$2" want="$3"
  local got
  got=$(eval_pins "$expr")
  if [[ "$got" == "$want" ]]; then
    pass "$label"
  else
    fail "$label (got='$got' want='$want')"
  fi
}

LIB='(import <nixpkgs> {}).lib'
RP="(import $RESOLVE { lib = $LIB; pinMap = import $PIN_MAP; })"

echo "== resolve-pins.nix =="

assert_pins "explicit pinnedApps wins" \
  "$RP {
    pinnedApps = [ \"firefox.desktop\" \"steam.desktop\" ];
    pinnedAppsAuto = true;
    packageModules = [ \"gaming\" ];
    systemPackages = [ \"chromium\" ];
    environment = \"plasma\";
  }" \
  "firefox.desktop steam.desktop"

assert_pins "auto: firefox + gaming + plasma defaults" \
  "$RP {
    pinnedApps = [];
    pinnedAppsAuto = true;
    packageModules = [ \"gaming\" ];
    systemPackages = [ \"firefox\" ];
    environment = \"plasma\";
  }" \
  "firefox.desktop steam.desktop vesktop.desktop com.heroicgameslauncher.hgl.desktop org.kde.dolphin.desktop org.kde.konsole.desktop"

assert_pins "auto off + empty explicit → nothing" \
  "$RP {
    pinnedApps = [];
    pinnedAppsAuto = false;
    packageModules = [ \"gaming\" ];
    systemPackages = [ \"firefox\" ];
    environment = \"plasma\";
  }" \
  ""

assert_pins "gnome defaults (no packages)" \
  "$RP {
    pinnedApps = [];
    pinnedAppsAuto = true;
    packageModules = [];
    systemPackages = [];
    environment = \"gnome\";
  }" \
  "org.gnome.Nautilus.desktop org.gnome.Terminal.desktop"

assert_pins "userPackagesFlat maps browsers" \
  "$RP {
    pinnedApps = [];
    pinnedAppsAuto = true;
    packageModules = [];
    systemPackages = [];
    userPackagesFlat = [ \"librewolf\" ];
    environment = \"xfce\";
  }" \
  "librewolf.desktop thunar.desktop xfce4-terminal.desktop"

assert_pins "unknown package ignored" \
  "$RP {
    pinnedApps = [];
    pinnedAppsAuto = true;
    packageModules = [];
    systemPackages = [ \"totally-not-a-mapped-pkg\" ];
    environment = \"plasma\";
  }" \
  "org.kde.dolphin.desktop org.kde.konsole.desktop"

echo
echo "========================================"
echo "resolve-pins: $PASS passed, $FAIL failed"
echo "========================================"
[[ $FAIL -eq 0 ]]
