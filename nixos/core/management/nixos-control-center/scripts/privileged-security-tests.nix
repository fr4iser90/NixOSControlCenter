# Escalation / policy tests for ncc-priv leaf model (no root required)
# Run: nix-build -E '...' or bash this script with POLICY lib from the store
{ pkgs, lib, getModuleConfig, getModuleMetadata }:

let
  priv = import ./privileged-helper.nix {
    inherit pkgs lib getModuleConfig getModuleMetadata;
  };
in
pkgs.writeShellScriptBin "ncc-priv-security-tests" ''
  set -euo pipefail
  export NCC_USER_ROLES=$(mktemp)
  cat > "$NCC_USER_ROLES" <<'EOF'
alice=guest
bob=admin
carol=restricted-admin
dave=virtualization
EOF
  export NCC_CONFIGS_BASE=/tmp/ncc-priv-test-sc
  # shellcheck disable=SC1091
  source "${priv.policyLib}"

  pass=0
  fail=0
  check() {
    local name="$1"
    shift
    if "$@"; then
      echo "PASS $name"
      pass=$((pass+1))
    else
      echo "FAIL $name"
      fail=$((fail+1))
    fi
  }
  check_false() {
    local name="$1"
    shift
    if "$@"; then
      echo "FAIL $name (expected deny)"
      fail=$((fail+1))
    else
      echo "PASS $name"
      pass=$((pass+1))
    fi
  }

  echo "=== ncc-priv security tests ==="

  # Package name validation
  check "pkg ok" ncc_priv_valid_pkg "firefox"
  check "pkg ok plus" ncc_priv_valid_pkg "gnome.gedit"
  check_false "pkg path" ncc_priv_valid_pkg "../etc/passwd"
  check_false "pkg slash" ncc_priv_valid_pkg "a/b"
  check_false "pkg semi" ncc_priv_valid_pkg 'foo;rm'
  check_false "pkg empty" ncc_priv_valid_pkg ""

  # Username
  check "user ok" ncc_priv_valid_username "alice"
  check_false "user dots" ncc_priv_valid_username "../bob"
  check_false "user slash" ncc_priv_valid_username "a/b"

  # Guest: self only
  check "guest self" ncc_priv_can_user_pkg "alice" "alice"
  check_false "guest other" ncc_priv_can_user_pkg "alice" "bob"
  check_false "guest system role" ncc_priv_can_system_pkg "alice"

  # Virt: self only for user pkgs
  check "virt self" ncc_priv_can_user_pkg "dave" "dave"
  check_false "virt other" ncc_priv_can_user_pkg "dave" "alice"
  check_false "virt system" ncc_priv_can_system_pkg "dave"

  # Admin / restricted
  check "admin other" ncc_priv_can_user_pkg "bob" "alice"
  check "admin system" ncc_priv_can_system_pkg "bob"
  check "radmin other" ncc_priv_can_user_pkg "carol" "alice"
  check "radmin system" ncc_priv_can_system_pkg "carol"

  # Leaf path confinement
  leaf=$(ncc_priv_user_leaf_path "alice")
  check "leaf path shape" test "$leaf" = "$NCC_CONFIGS_BASE/users/alice/config.nix"
  check "leaf safe" ncc_priv_assert_leaf_safe "alice" "$leaf"
  check_false "leaf escape" ncc_priv_assert_leaf_safe "alice" "$NCC_CONFIGS_BASE/core/base/desktop/config.nix"
  check_false "leaf other user" ncc_priv_assert_leaf_safe "alice" "$NCC_CONFIGS_BASE/users/bob/config.nix"
  check_false "leaf /etc" ncc_priv_assert_leaf_safe "alice" "/etc/passwd"
  check_false "leaf empty" ncc_priv_assert_leaf_safe "alice" ""

  # Unknown / root without role → guest → no cross-user
  check_false "root guest→alice" ncc_priv_can_user_pkg "root" "alice"
  check_false "unknown→other" ncc_priv_can_user_pkg "eve" "alice"
  check_false "user trav" ncc_priv_valid_username "alice/../bob"
  check_false "user \$inj" ncc_priv_valid_username 'alice$USER'
  check_false "pkg backtick" ncc_priv_valid_pkg 'foo`id`'
  check_false "pkg space" ncc_priv_valid_pkg "foo bar"

  # Account management policy
  check "admin manage" ncc_priv_can_user_manage "bob"
  check "radmin manage" ncc_priv_can_user_manage "carol"
  check_false "guest manage" ncc_priv_can_user_manage "alice"
  check_false "virt manage" ncc_priv_can_user_manage "dave"
  check "admin→admin role" ncc_priv_can_assign_role "bob" "admin"
  check "radmin→guest" ncc_priv_can_assign_role "carol" "guest"
  check_false "radmin→admin" ncc_priv_can_assign_role "carol" "admin"
  check_false "guest→role" ncc_priv_can_assign_role "alice" "guest"
  check "role ok" ncc_priv_valid_role "restricted-admin"
  check_false "role bad" ncc_priv_valid_role "root"
  check "shell ok" ncc_priv_valid_shell "zsh"
  check_false "shell bad" ncc_priv_valid_shell "powershell"

  ACCOUNTS='{"alice":{"role":"guest"},"bob":{"role":"admin"},"carol":{"role":"restricted-admin"}}'
  ONLY_ONE='{"bob":{"role":"admin"},"alice":{"role":"guest"}}'
  check "drop priv ok" ncc_priv_can_drop_privileged "carol" "restricted-admin" "$ACCOUNTS"
  check_false "drop last admin" ncc_priv_can_drop_privileged "bob" "admin" "$ONLY_ONE"
  check "demote keep priv" ncc_priv_can_drop_privileged "bob" "admin" "$ACCOUNTS" "restricted-admin"
  check_false "demote last" ncc_priv_can_drop_privileged "bob" "admin" "$ONLY_ONE" "guest"

  # Non-root helper must refuse writes (no leaf escalation without pkexec)
  mkdir -p "$NCC_CONFIGS_BASE/users/alice"
  if [[ "$(id -u)" -ne 0 ]]; then
    err=$(mktemp)
    if ${priv.helper}/bin/ncc-priv user-pkg add firefox --user alice 2>"$err"; then
      echo "FAIL non-root write refused"
      fail=$((fail+1))
    elif grep -q "must run as root" "$err"; then
      echo "PASS non-root write refused"
      pass=$((pass+1))
    else
      echo "FAIL non-root write refused (unexpected err)"
      cat "$err"
      fail=$((fail+1))
    fi
    rm -f "$err"
    if [[ -f "$NCC_CONFIGS_BASE/users/alice/config.nix" ]]; then
      echo "FAIL no write without elevation"
      fail=$((fail+1))
    else
      echo "PASS no write without elevation"
      pass=$((pass+1))
    fi
  fi

  echo "=== results: pass=$pass fail=$fail ==="
  rm -f "$NCC_USER_ROLES"
  rm -rf "$NCC_CONFIGS_BASE"
  [[ "$fail" -eq 0 ]]
''
