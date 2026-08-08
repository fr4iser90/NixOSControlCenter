# Runtime ncc user CLI — list/show/create/set/delete via config + ncc-priv
{ pkgs, getModuleMetadata }:

let
  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };
in
pkgs.writeShellScriptBin "ncc-user" ''
  set -euo pipefail
  SCRIPT_NAME="ncc user"
  export PATH="${pkgs.jq}/bin:${pkgs.coreutils}/bin:$PATH"

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$NIXOS_DIR/systemConfig"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"
  export NCC_USER_ROLES="''${NCC_USER_ROLES:-/etc/ncc/user-roles}"
  export JQ_BIN="${pkgs.jq}/bin/jq"
  export NIX_INSTANTIATE_BIN="${pkgs.nix}/bin/nix-instantiate"
  export NIX_BIN="${pkgs.nix}/bin/nix"

  usage() {
    cat <<EOF
$SCRIPT_NAME — User accounts and roles

Usage:
  $SCRIPT_NAME list [--json]
  $SCRIPT_NAME show <name> [--json]
  $SCRIPT_NAME whoami [--json]
  $SCRIPT_NAME create <name> --role ROLE [--shell SHELL] [--auto-login true|false] [--rebuild]
  $SCRIPT_NAME set <name> [--role ROLE] [--shell SHELL] [--auto-login true|false] [--rebuild]
  $SCRIPT_NAME delete <name> [--rebuild]

Roles: admin | restricted-admin | virtualization | guest
Shells: bash | zsh | fish

Account identity is stored in core/base/user/config.nix.
Per-user packages stay under users/<name>/config.nix.
EOF
  }

  role_of() {
    local user="$1" line u r
    [[ -f "$NCC_USER_ROLES" ]] || { echo "guest"; return 0; }
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      u="''${line%%=*}"
      r="''${line#*=}"
      [[ "$u" == "$user" ]] && { echo "$r"; return 0; }
    done < "$NCC_USER_ROLES"
    echo "guest"
  }

  accounts_json() {
    local tmp_nix tmp_json json="{}"
    tmp_json=$(mktemp --suffix=.json)
    if [[ -f "$MONOLITH_FILE" ]]; then
      tmp_nix=$(mktemp --suffix=.nix)
      cat > "$tmp_nix" <<NIX
let c = import $MONOLITH_FILE; in c.core.base.user or {}
NIX
      if ! "$NIX_INSTANTIATE_BIN" --eval --strict --json -E "import $tmp_nix" > "$tmp_json" 2>/dev/null; then
        printf '%s\n' '{}' > "$tmp_json"
      fi
      rm -f "$tmp_nix"
    else
      tmp_nix=$(mktemp --suffix=.nix)
      ncc_read_module_config "core/base/user" > "$tmp_nix" 2>/dev/null || printf '%s\n' '{}' > "$tmp_nix"
      if ! "$NIX_INSTANTIATE_BIN" --eval --strict --json -E "import $tmp_nix" > "$tmp_json" 2>/dev/null; then
        printf '%s\n' '{}' > "$tmp_json"
      fi
      rm -f "$tmp_nix"
    fi
    if ! ${pkgs.jq}/bin/jq -e . "$tmp_json" >/dev/null 2>&1; then
      printf '%s\n' '{}' > "$tmp_json"
    fi
    ${pkgs.jq}/bin/jq -c '
      to_entries
      | map(select(
          (.key | test("^(enable|_version)$") | not)
          and (.value | type == "object")
          and ((.value | has("role")) or (.value | has("defaultShell")))
        ))
      | map({
          name: .key,
          role: (.value.role // "guest"),
          shell: (.value.defaultShell // "bash"),
          autoLogin: (.value.autoLogin // false)
        })
      | sort_by(.name)
    ' "$tmp_json"
    rm -f "$tmp_json"
  }

  filter_for_viewer() {
    local me role
    me=$(id -un)
    role=$(role_of "$me")
    case "$role" in
      admin|restricted-admin) cat ;;
      *)
        jq --arg me "$me" '[.[] | select(.name == $me)]'
        ;;
    esac
  }

  cmd_list() {
    local json_out=false
    for a in "$@"; do
      case "$a" in --json|-j) json_out=true ;; esac
    done
    local data
    data=$(accounts_json | filter_for_viewer)
    if [[ "$json_out" == true ]]; then
      echo "$data" | jq -c '.'
    else
      echo "$data" | jq -r '.[] | "\(.name)=\(.role)=\(.shell)=\(.autoLogin)"'
    fi
  }

  cmd_show() {
    local name="''${1:-}" json_out=false
    shift || true
    for a in "$@"; do
      case "$a" in --json|-j) json_out=true ;; esac
    done
    [[ -n "$name" ]] || { echo "Usage: $SCRIPT_NAME show <name>" >&2; exit 2; }
    local row
    row=$(accounts_json | filter_for_viewer | jq -c --arg n "$name" '.[] | select(.name == $n)' | head -1)
    if [[ -z "$row" ]]; then
      echo "User not found (or not visible): $name" >&2
      exit 1
    fi
    if [[ "$json_out" == true ]]; then
      echo "$row"
    else
      echo "$row" | jq -r '"name=\(.name)", "role=\(.role)", "shell=\(.shell)", "autoLogin=\(.autoLogin)"'
    fi
  }

  cmd_whoami() {
    local json_out=false
    for a in "$@"; do
      case "$a" in --json|-j) json_out=true ;; esac
    done
    local me role
    me=$(id -un)
    role=$(role_of "$me")
    if [[ "$json_out" == true ]]; then
      jq -nc --arg u "$me" --arg r "$role" '{user:$u, role:$r, canManage: ($r == "admin" or $r == "restricted-admin")}'
    else
      echo "user=$me"
      echo "role=$role"
      if [[ "$role" == "admin" || "$role" == "restricted-admin" ]]; then
        echo "canManage=true"
      else
        echo "canManage=false"
      fi
    fi
  }

  elevate() {
    if command -v ncc-priv-run >/dev/null 2>&1; then
      ncc-priv-run "$@"
    elif [[ "$(id -u)" -eq 0 ]] && command -v ncc-priv >/dev/null 2>&1; then
      ncc-priv "$@"
    else
      echo "ncc-priv-run not found (rebuild NCC)" >&2
      exit 1
    fi
  }

  cmd_create() {
    local name="''${1:-}"
    shift || true
    [[ -n "$name" ]] || { echo "Usage: $SCRIPT_NAME create <name> --role ROLE ..." >&2; exit 2; }
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    elevate user-account create "$name" "$@"
  }

  cmd_set() {
    local name="''${1:-}"
    shift || true
    [[ -n "$name" ]] || { echo "Usage: $SCRIPT_NAME set <name> [--role ROLE] ..." >&2; exit 2; }
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    elevate user-account set "$name" "$@"
  }

  cmd_delete() {
    local name="''${1:-}"
    shift || true
    [[ -n "$name" ]] || { echo "Usage: $SCRIPT_NAME delete <name>" >&2; exit 2; }
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    elevate user-account delete "$name" "$@"
  }

  case "''${1:-}" in
    ""|help|-h|--help) usage ;;
    list) shift; cmd_list "$@" ;;
    show) shift; cmd_show "$@" ;;
    whoami) shift; cmd_whoami "$@" ;;
    create) shift; cmd_create "$@" ;;
    set) shift; cmd_set "$@" ;;
    delete|remove) shift; cmd_delete "$@" ;;
    *)
      echo "Unknown: $SCRIPT_NAME $1" >&2
      usage >&2
      exit 2
      ;;
  esac
''
