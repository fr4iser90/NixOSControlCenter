# ncc-priv — privileged config apply (leaf + account writes under /etc/nixos)
# User packages: systemConfig/users/<name>/config.nix
# Account defs:  systemConfig/core/base/user/config.nix (role, shell, autoLogin)
{ pkgs, lib, getModuleConfig, getModuleMetadata }:

let
  userCfg = getModuleConfig "user";
  userAttrs = lib.filterAttrs (_: v: builtins.isAttrs v) (
    if builtins.isAttrs userCfg then userCfg else {}
  );
  rolesText = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (u: c: "${u}=${c.role or "guest"}") userAttrs
  );
  rolesFile = pkgs.writeText "ncc-user-roles" (rolesText + "\n");

  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };

  policyLib = pkgs.writeText "ncc-priv-policy.sh" ''
    # shellcheck shell=bash

    ncc_priv_valid_username() {
      local u="$1"
      [[ "$u" =~ ^[a-z_][a-z0-9_-]*$ ]] || return 1
      [[ "$u" != *".."* ]] || return 1
      [[ "$u" != *"/"* ]] || return 1
      return 0
    }

    # NixOS logins are lowercase; normalize before validate
    ncc_priv_normalize_username() {
      local u="$1"
      echo "$u" | tr '[:upper:]' '[:lower:]'
    }

    ncc_priv_valid_pkg() {
      local p="$1"
      [[ "$p" =~ ^[a-zA-Z0-9][a-zA-Z0-9._+-]*$ ]] || return 1
      [[ "$p" != *".."* ]] || return 1
      [[ "$p" != *"/"* ]] || return 1
      [[ "$p" != *";"* ]] || return 1
      [[ "$p" != *"$"* ]] || return 1
      [[ "$p" != *"\`"* ]] || return 1
      return 0
    }

    ncc_priv_valid_role() {
      case "$1" in
        admin|restricted-admin|virtualization|guest) return 0 ;;
        *) return 1 ;;
      esac
    }

    ncc_priv_valid_shell() {
      case "$1" in
        bash|zsh|fish) return 0 ;;
        *) return 1 ;;
      esac
    }

    ncc_priv_role_of() {
      local user="$1" line u r
      [[ -f "''${NCC_USER_ROLES:-}" ]] || { echo "guest"; return 0; }
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        u="''${line%%=*}"
        r="''${line#*=}"
        if [[ "$u" == "$user" ]]; then
          echo "$r"
          return 0
        fi
      done < "$NCC_USER_ROLES"
      echo "guest"
    }

    ncc_priv_can_user_pkg() {
      local invoker="$1" target="$2" role
      role=$(ncc_priv_role_of "$invoker")
      case "$role" in
        admin|restricted-admin) return 0 ;;
        guest|virtualization)
          [[ "$invoker" == "$target" ]] && return 0
          return 1
          ;;
        *) return 1 ;;
      esac
    }

    ncc_priv_can_system_pkg() {
      local invoker="$1" role
      role=$(ncc_priv_role_of "$invoker")
      case "$role" in
        admin|restricted-admin) return 0 ;;
        *) return 1 ;;
      esac
    }

    # Account create / set / delete
    ncc_priv_can_user_manage() {
      local invoker="$1" role
      role=$(ncc_priv_role_of "$invoker")
      case "$role" in
        admin|restricted-admin) return 0 ;;
        *) return 1 ;;
      esac
    }

    # restricted-admin must not promote to admin
    ncc_priv_can_assign_role() {
      local invoker="$1" new_role="$2" role
      role=$(ncc_priv_role_of "$invoker")
      ncc_priv_valid_role "$new_role" || return 1
      case "$role" in
        admin) return 0 ;;
        restricted-admin)
          [[ "$new_role" != "admin" ]] && return 0
          return 1
          ;;
        *) return 1 ;;
      esac
    }

    ncc_priv_is_privileged_role() {
      case "$1" in
        admin|restricted-admin) return 0 ;;
        *) return 1 ;;
      esac
    }

    # roles_json: {"alice":{"role":"guest",...},...}
    # Deny removing/demoting the last privileged account
    ncc_priv_can_drop_privileged() {
      local target="$1" target_role="$2" roles_json="$3" new_role="''${4:-}"
      local count
      if ! ncc_priv_is_privileged_role "$target_role"; then
        return 0
      fi
      # demote only if new_role is non-privileged
      if [[ -n "$new_role" ]] && ncc_priv_is_privileged_role "$new_role"; then
        return 0
      fi
      count=$(echo "$roles_json" | jq '[to_entries[] | select(.value.role == "admin" or .value.role == "restricted-admin")] | length')
      [[ "''${count:-0}" -gt 1 ]]
    }

    ncc_priv_user_leaf_path() {
      local target="$1"
      local base="''${NCC_CONFIGS_BASE:-/etc/nixos/systemConfig}"
      local leaf="$base/users/$target/config.nix"
      case "$leaf" in
        "$base"/users/"$target"/config.nix) echo "$leaf"; return 0 ;;
        *) return 1 ;;
      esac
    }

    ncc_priv_assert_leaf_safe() {
      local target="$1" path="$2" base expected
      base="''${NCC_CONFIGS_BASE:-/etc/nixos/systemConfig}"
      expected="$base/users/$target/config.nix"
      [[ "$path" == "$expected" ]] || return 1
      if [[ -e "$path" ]]; then
        local real parent
        real=$(realpath -m "$path")
        parent=$(realpath -m "$base/users/$target")
        case "$real" in
          "$parent"/*|"$parent") ;;
          *) return 1 ;;
        esac
      fi
      return 0
    }
  '';

  helper = pkgs.writeShellScriptBin "ncc-priv" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    export PATH="${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:$PATH"
    export NCC_USER_ROLES="''${NCC_USER_ROLES:-/etc/ncc/user-roles}"
    NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
    export NCC_CONFIGS_BASE="''${NCC_CONFIGS_BASE:-$NIXOS_DIR/systemConfig}"

    # shellcheck disable=SC1091
    source "${policyLib}"

    ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
    export NIXOS_ROOT="$NIXOS_DIR"
    export CONFIGS_BASE="$NCC_CONFIGS_BASE"
    export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"
    export JQ_BIN="${pkgs.jq}/bin/jq"
    export NIX_INSTANTIATE_BIN="${pkgs.nix}/bin/nix-instantiate"
    export NIX_BIN="${pkgs.nix}/bin/nix"

    usage() {
      cat <<EOF
ncc-priv — privileged NCC config apply

Account definitions: core/base/user/config.nix
User packages leaf:  users/<name>/config.nix

Usage:
  ncc-priv user-pkg add|remove <pkg> [--user NAME] [--rebuild]
  ncc-priv user-account create <name> --role ROLE [--shell SHELL] [--auto-login true|false] [--rebuild]
  (optional password via env NCC_NEW_USER_PASSWORD)
  ncc-priv user-account set <name> [--role ROLE] [--shell SHELL] [--auto-login true|false] [--rebuild]
  ncc-priv user-account delete <name> [--rebuild]
  ncc-priv whoami
EOF
    }

    resolve_invoker() {
      if [[ -n "''${PKEXEC_UID:-}" ]]; then
        getent passwd "$PKEXEC_UID" | cut -d: -f1
        return
      fi
      if [[ -n "''${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
        echo "$SUDO_USER"
        return
      fi
      if [[ "$(id -u)" -eq 0 && -z "''${NCC_PRIV_ALLOW_ROOT_INVOKER:-}" ]]; then
        echo "root"
        return
      fi
      id -un
    }

    require_root() {
      if [[ "$(id -u)" -ne 0 ]]; then
        echo "ncc-priv: must run as root (use pkexec)" >&2
        exit 1
      fi
    }

    # Full module JSON (includes enable + users) — always validated
    read_user_module_json() {
      local tmp_nix tmp_json json
      tmp_json=$(mktemp --suffix=.json)
      if [[ -f "$MONOLITH_FILE" ]]; then
        tmp_nix=$(mktemp --suffix=.nix)
        cat > "$tmp_nix" <<NIX
let c = import $MONOLITH_FILE; in c.core.base.user or {}
NIX
        if ! "$NIX_INSTANTIATE_BIN" --eval --strict --json -E "import $tmp_nix" > "$tmp_json" 2>/dev/null; then
          echo '{}' > "$tmp_json"
        fi
        rm -f "$tmp_nix"
      else
        tmp_nix=$(mktemp --suffix=.nix)
        ncc_read_module_config "core/base/user" > "$tmp_nix" 2>/dev/null || echo "{}" > "$tmp_nix"
        if ! "$NIX_INSTANTIATE_BIN" --eval --strict --json -E "import $tmp_nix" > "$tmp_json" 2>/dev/null; then
          echo '{}' > "$tmp_json"
        fi
        rm -f "$tmp_nix"
      fi
      if ! jq -e . "$tmp_json" >/dev/null 2>&1; then
        echo '{}' > "$tmp_json"
      fi
      json=$(jq -c . "$tmp_json")
      rm -f "$tmp_json"
      echo "$json"
    }

    # Only account attrs
    users_accounts_json() {
      local full
      full=$(read_user_module_json)
      echo "$full" | jq -c '
        to_entries
        | map(select(
            (.key | test("^(enable|_version)$") | not)
            and (.value | type == "object")
            and ((.value | has("role")) or (.value | has("defaultShell")))
          ))
        | map({key: .key, value: {
            role: (.value.role // "guest"),
            defaultShell: (.value.defaultShell // "bash"),
            autoLogin: (.value.autoLogin // false)
          }})
        | from_entries
      '
    }

    write_user_module_json() {
      local full_json="$1"
      local tmp_json nix_out
      tmp_json=$(mktemp --suffix=.json)
      printf '%s\n' "$full_json" > "$tmp_json"
      if ! jq -e . "$tmp_json" >/dev/null 2>&1; then
        echo "ncc-priv: refusing to write invalid JSON" >&2
        rm -f "$tmp_json"
        return 1
      fi
      nix_out=$(_ncc_json_to_nix "$tmp_json") || { rm -f "$tmp_json"; return 1; }
      rm -f "$tmp_json"
      ncc_write_module_config "core/base/user" "$nix_out"
    }

    sync_roles_file() {
      local accounts path dir
      path="''${NCC_USER_ROLES:-/etc/ncc/user-roles}"
      dir=$(dirname "$path")
      mkdir -p "$dir" 2>/dev/null || return 0
      accounts=$(users_accounts_json) || return 0
      echo "$accounts" | jq -r 'to_entries[] | "\(.key)=\(.value.role)"' > "$path.tmp" 2>/dev/null || return 0
      mv -f "$path.tmp" "$path"
      chmod 644 "$path" 2>/dev/null || true
    }

    set_user_password_hash() {
      local name="$1" pass="''${2:-}" dir hash file="''${3:-}"
      if [[ -z "$pass" && -n "$file" && -f "$file" ]]; then
        pass=$(cat "$file")
        rm -f "$file"
      elif [[ -z "$pass" && -n "''${NCC_NEW_USER_PASSWORD_FILE:-}" && -f "$NCC_NEW_USER_PASSWORD_FILE" ]]; then
        pass=$(cat "$NCC_NEW_USER_PASSWORD_FILE")
        rm -f "$NCC_NEW_USER_PASSWORD_FILE"
      fi
      [[ -n "$pass" ]] || return 0
      dir="/etc/nixos/secrets/passwords/$name"
      mkdir -p /etc/nixos/secrets/passwords "$dir"
      chmod 700 /etc/nixos/secrets/passwords "$dir"
      hash=$(printf '%s' "$pass" | ${pkgs.mkpasswd}/bin/mkpasswd -m sha-512 -s)
      printf '%s\n' "$hash" > "$dir/.hashedPassword"
      chmod 600 "$dir/.hashedPassword"
      chown root:root "$dir/.hashedPassword"
    }

    ensure_user_leaf() {
      local name="$1" leaf
      leaf=$(ncc_priv_user_leaf_path "$name") || return 1
      ncc_priv_assert_leaf_safe "$name" "$leaf" || return 1
      mkdir -p "$(dirname "$leaf")"
      if [[ ! -f "$leaf" ]]; then
        printf '%s\n' "{ }" > "$leaf"
        chmod 644 "$leaf"
      fi
    }

    remove_user_leaf() {
      local name="$1" leaf dir
      leaf=$(ncc_priv_user_leaf_path "$name") || return 0
      ncc_priv_assert_leaf_safe "$name" "$leaf" || return 1
      rm -f "$leaf"
      dir=$(dirname "$leaf")
      rmdir "$dir" 2>/dev/null || true
    }

    add_user_pkg_file() {
      local path="$1" pkg="$2"
      mkdir -p "$(dirname "$path")"
      if [[ ! -f "$path" ]]; then
        printf '{\n  userPackages = [ "%s" ];\n}\n' "$pkg" > "$path"
        chmod 644 "$path"
        return 0
      fi
      if grep -qE "\"$pkg\"" "$path" 2>/dev/null; then
        echo "already present: $pkg"
        return 0
      fi
      if grep -qE '^[[:space:]]*userPackages[[:space:]]*=' "$path"; then
        if grep -qE '^[[:space:]]*userPackages[[:space:]]*=[[:space:]]*\[[[:space:]]*\]' "$path"; then
          sed -i -E "s|^([[:space:]]*userPackages[[:space:]]*=[[:space:]]*)\[[[:space:]]*\]|\1[ \"$pkg\" ]|" "$path"
        elif grep -qE '^[[:space:]]*userPackages[[:space:]]*=[[:space:]]*\[.*\][[:space:]]*;' "$path"; then
          sed -i -E "s|^([[:space:]]*userPackages[[:space:]]*=[[:space:]]*\[)(.*)(\][[:space:]]*;)|\1\2 \"$pkg\" \3|" "$path"
        else
          local tmp
          tmp=$(mktemp)
          awk -v pkg="$pkg" '
            BEGIN { inu=0 }
            /^[[:space:]]*userPackages[[:space:]]*=/ { inu=1 }
            inu && /^[[:space:]]*\]/ {
              printf "    \"%s\"\n", pkg
              inu=0
            }
            { print }
          ' "$path" > "$tmp"
          mv "$tmp" "$path"
        fi
      else
        if grep -qE '^\}[[:space:]]*$' "$path"; then
          sed -i -E "s|^\}[[:space:]]*$|  userPackages = [ \"$pkg\" ];\n}|" "$path"
        else
          printf '\nuserPackages = [ "%s" ];\n' "$pkg" >> "$path"
        fi
      fi
      chmod 644 "$path"
    }

    remove_user_pkg_file() {
      local path="$1" pkg="$2"
      [[ -f "$path" ]] || { echo "no config: $path" >&2; exit 1; }
      grep -qE "\"$pkg\"" "$path" || { echo "not found: $pkg" >&2; exit 1; }
      local tmp
      tmp=$(mktemp)
      sed -E "s|[[:space:]]*\"$pkg\"||g" "$path" > "$tmp"
      mv "$tmp" "$path"
      chmod 644 "$path"
    }

    maybe_rebuild() {
      if [[ "''${DO_REBUILD:-false}" == true ]]; then
        echo "Rebuilding system…"
        if command -v ncc >/dev/null 2>&1; then
          ncc system build switch
        else
          nixos-rebuild switch
        fi
      fi
    }

    cmd_user_pkg() {
      local action="''${1:-}"
      shift || true
      local pkg="" target=""
      DO_REBUILD=false
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --user) target="$2"; shift 2 ;;
          --rebuild) DO_REBUILD=true; shift ;;
          --help|-h) usage; exit 0 ;;
          *)
            if [[ -z "$pkg" ]]; then pkg="$1"; shift
            else echo "unexpected: $1" >&2; exit 2
            fi
            ;;
        esac
      done

      [[ -n "$action" && -n "$pkg" ]] || { echo "usage: ncc-priv user-pkg add|remove <pkg> [--user NAME] [--rebuild]" >&2; exit 2; }
      ncc_priv_valid_pkg "$pkg" || { echo "invalid package name: $pkg" >&2; exit 1; }

      require_root
      local invoker
      invoker=$(resolve_invoker)
      [[ -n "$target" ]] || target="$invoker"
      ncc_priv_valid_username "$target" || { echo "invalid username: $target" >&2; exit 1; }

      if ! ncc_priv_can_user_pkg "$invoker" "$target"; then
        echo "Permission denied: $invoker cannot modify userPackages for $target" >&2
        exit 1
      fi

      local leaf
      leaf=$(ncc_priv_user_leaf_path "$target") || { echo "refusing unsafe path" >&2; exit 1; }
      ncc_priv_assert_leaf_safe "$target" "$leaf" || { echo "path safety check failed" >&2; exit 1; }

      local layout
      layout=$(ncc_detect_layout 2>/dev/null || echo split)

      case "$layout" in
        monolith)
          local tmp content
          tmp=$(mktemp --suffix=.nix)
          ncc_read_module_config "users/$target" > "$tmp" 2>/dev/null || echo "{}" > "$tmp"
          case "$action" in
            add) add_user_pkg_file "$tmp" "$pkg" ;;
            remove) remove_user_pkg_file "$tmp" "$pkg" ;;
            *) echo "unknown action: $action" >&2; exit 2 ;;
          esac
          content=$(cat "$tmp")
          rm -f "$tmp"
          ncc_write_module_config "users/$target" "$content"
          ;;
        *)
          case "$action" in
            add) add_user_pkg_file "$leaf" "$pkg" ;;
            remove) remove_user_pkg_file "$leaf" "$pkg" ;;
            *) echo "unknown action: $action" >&2; exit 2 ;;
          esac
          ;;
      esac

      echo "OK: user-pkg $action $pkg → users/$target (invoker=$invoker)"
      maybe_rebuild
    }

    cmd_user_account() {
      local action="''${1:-}"
      shift || true
      local name="" role="" shell="" autologin="" password_file=""
      DO_REBUILD=false
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --role) role="$2"; shift 2 ;;
          --shell) shell="$2"; shift 2 ;;
          --auto-login) autologin="$2"; shift 2 ;;
          --password-file) password_file="$2"; shift 2 ;;
          --rebuild) DO_REBUILD=true; shift ;;
          --help|-h) usage; exit 0 ;;
          *)
            if [[ -z "$name" ]]; then name="$1"; shift
            else echo "unexpected: $1" >&2; exit 2
            fi
            ;;
        esac
      done

      [[ -n "$action" && -n "$name" ]] || {
        echo "usage: ncc-priv user-account create|set|delete <name> [options]" >&2
        exit 2
      }
      name=$(ncc_priv_normalize_username "$name")
      ncc_priv_valid_username "$name" || {
        echo "invalid username: $name (use lowercase a-z, 0-9, _, -)" >&2
        exit 1
      }

      require_root
      local invoker
      invoker=$(resolve_invoker)

      if ! ncc_priv_can_user_manage "$invoker"; then
        echo "Permission denied: $invoker cannot manage user accounts" >&2
        exit 1
      fi

      local full accounts
      full=$(read_user_module_json)
      if ! printf '%s' "$full" | jq -e . >/dev/null 2>&1; then
        echo "ncc-priv: failed to read core.base.user as JSON" >&2
        exit 1
      fi
      accounts=$(users_accounts_json)

      case "$action" in
        create)
          [[ -n "$role" ]] || role="guest"
          [[ -n "$shell" ]] || shell="bash"
          [[ -n "$autologin" ]] || autologin="false"
          ncc_priv_valid_role "$role" || { echo "invalid role: $role" >&2; exit 1; }
          ncc_priv_valid_shell "$shell" || { echo "invalid shell: $shell" >&2; exit 1; }
          case "$autologin" in true|false) ;; *) echo "auto-login must be true|false" >&2; exit 1 ;; esac
          if ! ncc_priv_can_assign_role "$invoker" "$role"; then
            echo "Permission denied: cannot assign role $role" >&2
            exit 1
          fi
          if echo "$accounts" | jq -e --arg n "$name" 'has($n)' >/dev/null; then
            echo "user already exists: $name" >&2
            exit 1
          fi
          full=$(printf '%s' "$full" | jq -c --arg n "$name" --arg r "$role" --arg s "$shell" --arg a "$autologin" '
            .[$n] = { role: $r, defaultShell: $s, autoLogin: ($a == "true") }
          ')
          write_user_module_json "$full"
          ensure_user_leaf "$name"
          set_user_password_hash "$name" "''${NCC_NEW_USER_PASSWORD:-}" "$password_file"
          unset NCC_NEW_USER_PASSWORD || true
          sync_roles_file
          echo "OK: created user $name role=$role shell=$shell (invoker=$invoker)"
          ;;
        set)
          if ! echo "$accounts" | jq -e --arg n "$name" 'has($n)' >/dev/null; then
            echo "user not found: $name" >&2
            exit 1
          fi
          local cur_role
          cur_role=$(echo "$accounts" | jq -r --arg n "$name" '.[$n].role')
          if [[ -n "$role" ]]; then
            ncc_priv_valid_role "$role" || { echo "invalid role: $role" >&2; exit 1; }
            if ! ncc_priv_can_assign_role "$invoker" "$role"; then
              echo "Permission denied: cannot assign role $role" >&2
              exit 1
            fi
            if ! ncc_priv_can_drop_privileged "$name" "$cur_role" "$accounts" "$role"; then
              echo "refusing: cannot demote the last admin/restricted-admin" >&2
              exit 1
            fi
          fi
          if [[ -n "$shell" ]]; then
            ncc_priv_valid_shell "$shell" || { echo "invalid shell: $shell" >&2; exit 1; }
          fi
          if [[ -n "$autologin" ]]; then
            case "$autologin" in true|false) ;; *) echo "auto-login must be true|false" >&2; exit 1 ;; esac
          fi
          full=$(echo "$full" | jq --arg n "$name" \
            --arg r "$role" --arg s "$shell" --arg a "$autologin" '
            .[$n].role = (if $r == "" then .[$n].role else $r end)
            | .[$n].defaultShell = (if $s == "" then .[$n].defaultShell else $s end)
            | .[$n].autoLogin = (if $a == "" then .[$n].autoLogin else ($a == "true") end)
          ')
          write_user_module_json "$full"
          set_user_password_hash "$name" "''${NCC_NEW_USER_PASSWORD:-}" "$password_file"
          unset NCC_NEW_USER_PASSWORD || true
          sync_roles_file
          echo "OK: updated user $name (invoker=$invoker)"
          ;;
        delete)
          if ! echo "$accounts" | jq -e --arg n "$name" 'has($n)' >/dev/null; then
            echo "user not found: $name" >&2
            exit 1
          fi
          cur_role=$(echo "$accounts" | jq -r --arg n "$name" '.[$n].role')
          if ! ncc_priv_can_drop_privileged "$name" "$cur_role" "$accounts"; then
            echo "refusing: cannot delete the last admin/restricted-admin" >&2
            exit 1
          fi
          # restricted-admin cannot delete an admin
          if [[ "$(ncc_priv_role_of "$invoker")" == "restricted-admin" && "$cur_role" == "admin" ]]; then
            echo "Permission denied: restricted-admin cannot delete admin users" >&2
            exit 1
          fi
          full=$(echo "$full" | jq --arg n "$name" 'del(.[$n])')
          write_user_module_json "$full"
          remove_user_leaf "$name"
          sync_roles_file
          echo "OK: deleted user $name (invoker=$invoker)"
          ;;
        *)
          echo "unknown action: $action" >&2
          exit 2
          ;;
      esac
      maybe_rebuild
    }

    if [[ "''${NCC_PRIV_POLICY_ONLY:-0}" == 1 ]]; then
      exit 0
    fi

    case "''${1:-}" in
      ""|help|-h|--help) usage; exit 0 ;;
      whoami)
        inv=$(resolve_invoker)
        echo "invoker=$inv"
        echo "role=$(ncc_priv_role_of "$inv")"
        echo "uid=$(id -u)"
        echo "euid=$(id -u)"
        echo "roles_file=$NCC_USER_ROLES"
        ;;
      user-pkg)
        shift
        cmd_user_pkg "$@"
        ;;
      user-account)
        shift
        cmd_user_account "$@"
        ;;
      *)
        echo "Unknown: ncc-priv $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  '';

  # Elevate — prefer passwordless sudo; password via temp file + --password-file
  wrapper = pkgs.writeShellScriptBin "ncc-priv-run" ''
    set -euo pipefail
    PWFILE=""
    cleanup() { [[ -n "$PWFILE" && -f "$PWFILE" ]] && rm -f "$PWFILE" || true; }
    trap cleanup EXIT
    EXTRA=()
    if [[ -n "''${NCC_NEW_USER_PASSWORD:-}" ]]; then
      PWFILE=$(mktemp)
      printf '%s' "$NCC_NEW_USER_PASSWORD" > "$PWFILE"
      chmod 600 "$PWFILE"
      unset NCC_NEW_USER_PASSWORD
      EXTRA+=(--password-file "$PWFILE")
    elif [[ -n "''${NCC_NEW_USER_PASSWORD_FILE:-}" && -f "$NCC_NEW_USER_PASSWORD_FILE" ]]; then
      EXTRA+=(--password-file "$NCC_NEW_USER_PASSWORD_FILE")
    fi
    if [[ "$(id -u)" -eq 0 ]]; then
      trap - EXIT
      exec ${helper}/bin/ncc-priv "$@" "''${EXTRA[@]}"
    fi
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      trap - EXIT
      exec sudo -n ${helper}/bin/ncc-priv "$@" "''${EXTRA[@]}"
    fi
    if command -v pkexec >/dev/null 2>&1; then
      trap - EXIT
      exec pkexec ${helper}/bin/ncc-priv "$@" "''${EXTRA[@]}"
    fi
    if command -v sudo >/dev/null 2>&1; then
      trap - EXIT
      exec sudo ${helper}/bin/ncc-priv "$@" "''${EXTRA[@]}"
    fi
    echo "Need pkexec or sudo to apply config changes." >&2
    exit 1
  '';

  polkitPolicy = pkgs.writeText "org.nixos.ncc.priv.policy" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC
     "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
    <policyconfig>
      <vendor>NixOS Control Center</vendor>
      <action id="org.nixos.ncc.priv.user-leaf">
        <description>NCC: modify user packages or accounts under systemConfig</description>
        <message>Authentication is required to update NCC user configuration</message>
        <defaults>
          <allow_any>auth_admin</allow_any>
          <allow_inactive>auth_admin</allow_inactive>
          <allow_active>auth_admin</allow_active>
        </defaults>
        <annotate key="org.freedesktop.policykit.exec.path">${helper}/bin/ncc-priv</annotate>
        <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
      </action>
    </policyconfig>
  '';

in {
  inherit helper wrapper policyLib rolesFile polkitPolicy;

  nixosModule = {
    environment.systemPackages = [ helper wrapper ];
    # Mutable roles file (helper syncs after account changes; activation reseeds from config)
    system.activationScripts.ncc-user-roles = {
      text = ''
        mkdir -p /etc/ncc
        cp ${rolesFile} /etc/ncc/user-roles
        chmod 644 /etc/ncc/user-roles
      '';
    };
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.nixos.ncc.priv.user-leaf" && subject.active) {
          return polkit.Result.AUTH_ADMIN;
        }
      });
    '';
    environment.etc."polkit-1/actions/org.nixos.ncc.priv.policy".source = polkitPolicy;
  };
}
