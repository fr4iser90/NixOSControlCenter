# Runtime ncc user CLI — list/show/create/set/delete via config + ncc-priv
{ pkgs, getModuleMetadata, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";
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
  $SCRIPT_NAME create <name> --role ROLE [--shell SHELL] [--auto-login true|false] [--rebuild] [--dry-run]
  $SCRIPT_NAME set <name> [--role ROLE] [--shell SHELL] [--auto-login true|false] [--rebuild] [--dry-run]
  $SCRIPT_NAME delete <name> [--rebuild] [--dry-run]

Roles: admin | restricted-admin | virtualization | guest
Shells: bash | zsh | fish

--dry-run   Preview mutate — prints intended ncc-priv action; no writes

Account identity is stored in core/base/user/config.nix.
Per-user packages stay under users/<name>/config.nix.
EOF
  }

  role_of() {
    local user="$1" line u r
    if [[ -f "$NCC_USER_ROLES" ]]; then
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        u="''${line%%=*}"
        r="''${line#*=}"
        [[ "$u" == "$user" ]] && { echo "$r"; return 0; }
      done < "$NCC_USER_ROLES"
    fi
    # Fallback when roles file missing/stale or user absent (e.g. pre-activation)
    r=$(accounts_json | ${pkgs.jq}/bin/jq -r --arg u "$user" '
      [.[] | select(.name == $u) | .role] | first // empty
    ' 2>/dev/null || true)
    [[ -n "$r" ]] && { echo "$r"; return 0; }
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
    if [[ "$json_out" != true && -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "User list"}
    fi
    if [[ "$json_out" != true ]]; then
      ${ui.messages.loading "Reading accounts…"}
    fi
    local data
    data=$(accounts_json | filter_for_viewer)
    if [[ "$json_out" == true ]]; then
      echo "$data" | jq -c '.'
    else
      echo "$data" | jq -r '.[] | "\(.name)=\(.role)=\(.shell)=\(.autoLogin)"'
      ${ui.messages.success "Account list ready"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user show <name>"}
      fi
    fi
  }

  cmd_show() {
    local name="''${1:-}" json_out=false
    shift || true
    for a in "$@"; do
      case "$a" in --json|-j) json_out=true ;; esac
    done
    if [[ -z "$name" ]]; then
      ${ui.messages.error "Usage: $SCRIPT_NAME show <name>"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user list"}
      fi
      exit 2
    fi
    if [[ "$json_out" != true && -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "User show"}
    fi
    if [[ "$json_out" != true ]]; then
      ${ui.messages.loading "Looking up $name…"}
      ${ui.tables.keyValue "user" "$name"}
    fi
    local row
    row=$(accounts_json | filter_for_viewer | jq -c --arg n "$name" '.[] | select(.name == $n)' | head -1)
    if [[ -z "$row" ]]; then
      ${ui.messages.error "User not found (or not visible): $name"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user list"}
      fi
      exit 1
    fi
    if [[ "$json_out" == true ]]; then
      echo "$row"
    else
      echo "$row" | jq -r '"name=\(.name)", "role=\(.role)", "shell=\(.shell)", "autoLogin=\(.autoLogin)"'
      ${ui.messages.success "User details ready"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user set $name --role ROLE"}
      fi
    fi
  }

  cmd_whoami() {
    local json_out=false
    for a in "$@"; do
      case "$a" in --json|-j) json_out=true ;; esac
    done
    if [[ "$json_out" != true && -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "User whoami"}
    fi
    local me role
    me=$(id -un)
    role=$(role_of "$me")
    if [[ "$json_out" == true ]]; then
      jq -nc --arg u "$me" --arg r "$role" '{user:$u, role:$r, canManage: ($r == "admin" or $r == "restricted-admin")}'
    else
      ${ui.tables.keyValue "user" "$me"}
      ${ui.tables.keyValue "role" "$role"}
      if [[ "$role" == "admin" || "$role" == "restricted-admin" ]]; then
        ${ui.tables.keyValue "canManage" "true"}
      else
        ${ui.tables.keyValue "canManage" "false"}
      fi
      ${ui.messages.success "Identity ready"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user list"}
      fi
    fi
  }

  elevate() {
    if command -v ncc-priv-run >/dev/null 2>&1; then
      ncc-priv-run "$@"
    elif [[ "$(id -u)" -eq 0 ]] && command -v ncc-priv >/dev/null 2>&1; then
      ncc-priv "$@"
    else
      ${ui.messages.error "ncc-priv-run not found (rebuild NCC)"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: sudo ncc system update --local --source-dir /path/to/NixOSControlCenter/nixos"}
      fi
      exit 1
    fi
  }

  cmd_create() {
    local name="''${1:-}"
    shift || true
    local dry_run=false
    local rest=()
    for a in "$@"; do
      case "$a" in
        --dry-run|-d) dry_run=true ;;
        *) rest+=("$a") ;;
      esac
    done
    if [[ -z "$name" ]]; then
      ${ui.messages.error "Usage: $SCRIPT_NAME create <name> --role ROLE ... [--dry-run]"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user create <name> --role guest"}
      fi
      exit 2
    fi
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      if [[ "$dry_run" == true ]]; then
        ${ui.text.header "User create (dry-run)"}
        ${ui.messages.info "Preview only — nothing will be written…"}
      else
        ${ui.text.header "User create"}
      fi
    fi
    ${ui.messages.loading "Creating account $name…"}
    ${ui.tables.keyValue "user" "$name"}
    if [[ ''${#rest[@]} -gt 0 ]]; then
      _args="''${rest[*]}"
      ${ui.tables.keyValue "args" "$_args"}
    fi
    if [[ "$dry_run" == true ]]; then
      ${ui.messages.success "Would create user '$name' via ncc-priv (dry-run) — no changes written"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        _args="''${rest[*]}"
        ${ui.messages.info "Next: ncc user create $name $_args"}
      fi
      exit 0
    fi
    elevate user-account create "$name" "''${rest[@]}"
    ${ui.messages.success "Create request submitted for $name"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc user show $name"}
    fi
  }

  cmd_set() {
    local name="''${1:-}"
    shift || true
    local dry_run=false
    local rest=()
    for a in "$@"; do
      case "$a" in
        --dry-run|-d) dry_run=true ;;
        *) rest+=("$a") ;;
      esac
    done
    if [[ -z "$name" ]]; then
      ${ui.messages.error "Usage: $SCRIPT_NAME set <name> [--role ROLE] ... [--dry-run]"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user set <name> --role guest"}
      fi
      exit 2
    fi
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      if [[ "$dry_run" == true ]]; then
        ${ui.text.header "User set (dry-run)"}
        ${ui.messages.info "Preview only — nothing will be written…"}
      else
        ${ui.text.header "User set"}
      fi
    fi
    ${ui.messages.loading "Updating account $name…"}
    ${ui.tables.keyValue "user" "$name"}
    if [[ ''${#rest[@]} -gt 0 ]]; then
      _args="''${rest[*]}"
      ${ui.tables.keyValue "args" "$_args"}
    fi
    if [[ "$dry_run" == true ]]; then
      ${ui.messages.success "Would update user '$name' via ncc-priv (dry-run) — no changes written"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        _args="''${rest[*]}"
        ${ui.messages.info "Next: ncc user set $name $_args"}
      fi
      exit 0
    fi
    elevate user-account set "$name" "''${rest[@]}"
    ${ui.messages.success "Update request submitted for $name"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc user show $name"}
    fi
  }

  cmd_delete() {
    local name="''${1:-}"
    shift || true
    local dry_run=false
    local rest=()
    for a in "$@"; do
      case "$a" in
        --dry-run|-d) dry_run=true ;;
        *) rest+=("$a") ;;
      esac
    done
    if [[ -z "$name" ]]; then
      ${ui.messages.error "Usage: $SCRIPT_NAME delete <name> [--dry-run]"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user list"}
      fi
      exit 2
    fi
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      if [[ "$dry_run" == true ]]; then
        ${ui.text.header "User delete (dry-run)"}
        ${ui.messages.info "Preview only — nothing will be written…"}
      else
        ${ui.text.header "User delete"}
      fi
    fi
    ${ui.messages.loading "Deleting account $name…"}
    ${ui.tables.keyValue "user" "$name"}
    if [[ "$dry_run" == true ]]; then
      ${ui.messages.success "Would delete user '$name' via ncc-priv (dry-run) — no changes written"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user delete $name"}
      fi
      exit 0
    fi
    elevate user-account delete "$name" "''${rest[@]}"
    ${ui.messages.success "Delete request submitted for $name"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc user list"}
    fi
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
      ${ui.messages.error "Unknown: $SCRIPT_NAME $1"}
      usage >&2
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc user list"}
      fi
      exit 2
      ;;
  esac
''
