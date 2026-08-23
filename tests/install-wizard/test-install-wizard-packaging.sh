#!/usr/bin/env bash
# Regression: stale install-wizard scripts/checks/ + `{ pkgs }:` leftovers must not
# break packaging when commands.nix passes getModuleApi.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS="$ROOT/nixos/core/management/install-wizard/scripts"
DEFAULT="$SCRIPTS/default.nix"

echo "== static: packaging guards in scripts/default.nix =="
grep -q 'rel == "checks"' "$DEFAULT" || {
  echo "FAIL: skipDir must skip obsolete checks/"
  exit 1
}
grep -q 'builtins.functionArgs' "$DEFAULT" || {
  echo "FAIL: callScript must use functionArgs for getModuleApi"
  exit 1
}
grep -q 'fa ? getModuleApi' "$DEFAULT" || {
  echo "FAIL: getModuleApi only when declared"
  exit 1
}
grep -q 'fa ? getModuleMetadata' "$DEFAULT" || {
  echo "FAIL: getModuleMetadata only when declared"
  exit 1
}
echo "OK static guards"

echo "== dynamic: leftover { pkgs }: + skipDir(checks) =="
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/checks/hardware" "$TMP/lib"
cat >"$TMP/checks/hardware/cpu.nix" <<'EOF'
{ pkgs }:
pkgs.writeText "cpu.sh" ''
#!/usr/bin/env bash
echo stale
''
EOF
cat >"$TMP/lib/stale-pkgs-only.nix" <<'EOF'
{ pkgs }:
pkgs.writeText "stale-pkgs-only.sh" ''
#!/usr/bin/env bash
echo stale
''
EOF

# 1) Direct call with getModuleApi must fail on legacy { pkgs }:
if nix-instantiate --eval -E "
  let pkgs = import <nixpkgs> {};
      fn = import $TMP/checks/hardware/cpu.nix;
  in fn { inherit pkgs; getModuleApi = null; }
" >/dev/null 2>/tmp/ncc-iw-unexpected.err; then
  echo "FAIL: expected unexpected-argument error for getModuleApi on { pkgs }:"
  exit 1
fi
grep -q "unexpected argument" /tmp/ncc-iw-unexpected.err || {
  echo "FAIL: wrong error (expected unexpected argument getModuleApi)"
  cat /tmp/ncc-iw-unexpected.err
  exit 1
}
echo "OK: bare getModuleApi on { pkgs }: fails (the Gaming bug)"

# 2) callScript pattern (functionArgs) must succeed
nix-build --no-out-link -E "
  let
    pkgs = import <nixpkgs> {};
    callScript = path:
      let
        fn = import path;
        fa = builtins.functionArgs fn;
      in
      if fa ? getModuleApi then fn { inherit pkgs; getModuleApi = null; }
      else fn { inherit pkgs; };
  in
  callScript $TMP/lib/stale-pkgs-only.nix
" >/dev/null
echo "OK: functionArgs callScript packages { pkgs }: leftovers"

# 3) skipDir must exclude checks/ from collection (real scripts tree + injected checks)
cp -a "$SCRIPTS" "$TMP/scripts"
mkdir -p "$TMP/scripts/checks/hardware"
cp "$TMP/checks/hardware/cpu.nix" "$TMP/scripts/checks/hardware/cpu.nix"

nix-instantiate --eval --strict -E "
  let
    pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
    skipDir = rel:
      rel == \"setup/modes/host-blueprints\"
      || rel == \"setup/modes/install-bases\"
      || rel == \"checks\"
      || lib.hasPrefix \"checks/\" rel;
    collect = dir: prefix:
      let entries = builtins.readDir dir; in
      lib.concatLists (lib.mapAttrsToList (name: type:
        let
          rel = if prefix == \"\" then name else \"\${prefix}/\${name}\";
          path = dir + \"/\${name}\";
        in
        if type == \"directory\" then
          if skipDir rel then [] else collect path rel
        else if type == \"regular\" && lib.hasSuffix \".nix\" name && !(prefix == \"\" && name == \"default.nix\") then
          [ rel ]
        else []
      ) entries);
    rels = collect $TMP/scripts \"\";
    bad = builtins.filter (r: lib.hasPrefix \"checks/\" r) rels;
  in
  assert bad == [];
  \"skip-ok\"
" >/dev/null
echo "OK: skipDir excludes checks/ even when present on disk"

# 4) Real repo packaging still builds (needs getModuleApi "packages" + "cli-formatter")
nix-build --no-out-link -E "
  let
    pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
    helpers = import $ROOT/nixos/core/management/module-manager/lib/module-config.nix {
      inherit lib;
      systemConfig = {};
    };
    inherit (helpers) getModuleApi getModuleMetadata;
  in
  (import $SCRIPTS { inherit pkgs getModuleApi getModuleMetadata; }).scriptTree
" >/dev/null
echo "OK: real scripts/default.nix scriptTree builds"


echo "PASS: install-wizard packaging regression"
