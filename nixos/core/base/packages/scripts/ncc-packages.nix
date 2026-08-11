{ pkgs, getModuleMetadata }:

let
  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };
  catalogFile = import ../lib/mk-catalog-json.nix { inherit pkgs; };
in
pkgs.writeShellScriptBin "ncc-packages" ''
  # User-facing name only — never show the internal binary (ncc-packages)
  SCRIPT_NAME="ncc packages"
  VERSION="2.1.0"

  set -euo pipefail

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  SYSTEM_CONFIG="$NIXOS_DIR/systemConfig"
  MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  # Allow NIXOS_DIR override after preamble
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$SYSTEM_CONFIG"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

  CATALOG_JSON="''${NCC_PACKAGES_CATALOG:-${catalogFile}}"
  JQ="${pkgs.jq}/bin/jq"
  NIX_SHELL_BIN="${pkgs.nix}/bin/nix-shell"

  # (path helpers below stage monolith edits and flush on EXIT)

  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'

  log_info()    { echo -e "$BLUE"'[i]'"$NC $*"; }
  log_success() { echo -e "$GREEN"'[+]'"$NC $*"; }
  log_warn()    { echo -e "$YELLOW"'[!]'"$NC $*"; }
  log_error()   { echo -e "$RED"'[-]'"$NC $*" >&2; }

  COMMAND=""
  SUBCOMMAND=""
  PACKAGE=""
  TARGET_USER=""
  TARGET_SYSTEM=false
  JSON_OUT=false
  PACKAGES=()
  NAMES=()
  QUERY=""
  # Rebuild prompt after mutating config (like system-update)
  SKIP_BUILD_PROMPT=false
  AUTO_BUILD=false
  CONFIG_CHANGED=false

  usage() {
      cat << EOF
  $SCRIPT_NAME - Package Management CLI

  Usage:
    Single packages (nixpkgs):
      $SCRIPT_NAME add <package>... [--user <name>] [--system]
      $SCRIPT_NAME remove <package>... [--user <name>] [--system]
      $SCRIPT_NAME list [--system] [--json]

    Store (intent search / try) — individual apps → userPackages:
      $SCRIPT_NAME search <query> [--json]   Search curated apps (+ rare tips)
      $SCRIPT_NAME resolve <query> [--json]  Best match → packages add action
      $SCRIPT_NAME try <package>             Temporary nix-shell -p (no config write)
      $SCRIPT_NAME categories [--json]       List Store categories

    Module sets and presets (packageModules / userPackages):
      $SCRIPT_NAME module list                 List active packageModules
      $SCRIPT_NAME module available            Show sets and presets (system|user)
      $SCRIPT_NAME module add <name>...        Add set(s) and/or preset(s)
      $SCRIPT_NAME module remove <name>...     Remove set(s) or user-preset packages
      $SCRIPT_NAME module info <name>          Show details for a set or preset

    User presets (scope = \"user\") write users.<you>.userPackages via ncc-priv.
    System presets / sets write packageModules (needs root). Use GUI tab Sets & recipes.

  Flags:
    --system       Target systemPackages (global, all users)
    --user <name>  Target a specific user's userPackages
    --json         Machine-readable list output
    -y, --yes      After changes, build+switch without asking
    --no-build     After changes, skip rebuild prompt
    -h, --help     Show this help message
    -v, --version  Show version

  Defaults:
    Without flags, single-package operations target the current user's userPackages.
    Module operations edit core.base.packages via config-facade
    (monolith: systemConfig.nix | split: systemConfig/core/base/packages/config.nix).
    After add/remove, you are prompted to rebuild so packages become active.
    resolve recommends a Store app attr (e.g. OBS → add obs-studio). Bundles:
    ncc packages module add streaming|gaming|gaming-desktop (Sets & recipes).

  Layout:
    ncc system config-layout detect
    ncc system config-layout convert --to monolith|split

  Examples:
    $SCRIPT_NAME add vscode                          Add vscode to current user
    $SCRIPT_NAME add nginx --system                  Add nginx to systemPackages
    $SCRIPT_NAME list                                List all single packages

    $SCRIPT_NAME search obs                          Find OBS Studio (user app)
    $SCRIPT_NAME resolve obs --json                  → packages add obs-studio
    $SCRIPT_NAME try firefox                         Try firefox in a temp shell
    $SCRIPT_NAME module add streaming                Full OBS stack (set)

    $SCRIPT_NAME module available                    Show what can be enabled
    $SCRIPT_NAME module add gaming                   Enable single set
    $SCRIPT_NAME module add gaming-desktop           Apply system preset (sets)
    $SCRIPT_NAME module add user-web-tools           Apply user preset (userPackages)
    $SCRIPT_NAME module add gaming streaming         Add multiple sets at once
    $SCRIPT_NAME module remove emulation             Remove a single set
    $SCRIPT_NAME module info gaming-desktop          Show what a preset contains
    $SCRIPT_NAME module add gaming -y                Add gaming and rebuild immediately

  EOF
      exit 0
  }

  version() {
      echo "$SCRIPT_NAME $VERSION"
      exit 0
  }

  # ----------------------------------------------------------------------------
  # Argument parsing
  # ----------------------------------------------------------------------------

  parse_args() {
      if [[ $# -eq 0 ]]; then
          usage
      fi

      COMMAND="$1"
      shift

      case "$COMMAND" in
          add|remove|list)
              parse_package_args "$@"
              ;;
          search|resolve|try)
              parse_query_args "$@"
              ;;
          categories)
              parse_categories_args "$@"
              ;;
          module)
              parse_module_args "$@"
              ;;
          -h|--help|help) usage ;;
          -v|--version) version ;;
          gui)
              log_error "Open the GUI with: ncc packages"
              exit 1
              ;;
          *)
              log_error "Unknown command: $COMMAND"
              echo "Valid commands: add, remove, list, search, resolve, try, categories, module"
              echo "GUI: ncc packages"
              exit 1
              ;;
      esac
  }

  parse_build_flag() {
      case "$1" in
          -y|--yes)
              AUTO_BUILD=true
              ;;
          --no-build)
              SKIP_BUILD_PROMPT=true
              ;;
          *)
              return 1
              ;;
      esac
      return 0
  }

  parse_package_args() {
      while [[ $# -gt 0 ]]; do
          case "$1" in
              --system)
                  TARGET_SYSTEM=true
                  shift
                  ;;
              --user)
                  if [[ $# -lt 2 ]] || [[ -z "$2" ]]; then
                      log_error "--user requires a username argument"
                      exit 1
                  fi
                  TARGET_USER="$2"
                  shift 2
                  ;;
              --json|-j)
                  JSON_OUT=true
                  shift
                  ;;
              -y|--yes|--no-build)
                  parse_build_flag "$1"
                  shift
                  ;;
              -h|--help) usage ;;
              -v|--version) version ;;
              -*)
                  log_error "Unknown flag: $1"
                  exit 1
                  ;;
              *)
                  PACKAGES+=("$1")
                  if [[ -z "$PACKAGE" ]]; then
                      PACKAGE="$1"
                  fi
                  shift
                  ;;
          esac
      done

      if [[ "$COMMAND" != "list" ]] && [[ ''${#PACKAGES[@]} -eq 0 ]]; then
          log_error "Missing package name. Usage: $SCRIPT_NAME $COMMAND <package>... [flags]"
          exit 1
      fi
  }

  parse_query_args() {
      while [[ $# -gt 0 ]]; do
          case "$1" in
              --json|-j)
                  JSON_OUT=true
                  shift
                  ;;
              -h|--help) usage ;;
              -*)
                  log_error "Unknown flag: $1"
                  exit 1
                  ;;
              *)
                  if [[ -n "$QUERY" ]]; then
                      QUERY="$QUERY $1"
                  else
                      QUERY="$1"
                  fi
                  # try also accepts as PACKAGE for shell
                  PACKAGES+=("$1")
                  if [[ -z "$PACKAGE" ]]; then
                      PACKAGE="$1"
                  fi
                  shift
                  ;;
          esac
      done
      if [[ -z "$QUERY" ]]; then
          log_error "Missing query. Usage: $SCRIPT_NAME $COMMAND <query>"
          exit 1
      fi
  }

  parse_categories_args() {
      while [[ $# -gt 0 ]]; do
          case "$1" in
              --json|-j)
                  JSON_OUT=true
                  shift
                  ;;
              -h|--help) usage ;;
              -*)
                  log_error "Unknown flag: $1"
                  exit 1
                  ;;
              *)
                  log_error "Unexpected argument: $1"
                  exit 1
                  ;;
          esac
      done
  }

  parse_module_args() {
      if [[ $# -eq 0 ]]; then
          log_error "Missing module subcommand"
          echo "Valid subcommands: list, available, add, remove, info"
          exit 1
      fi

      SUBCOMMAND="$1"
      shift

      case "$SUBCOMMAND" in
          list|available)
              while [[ $# -gt 0 ]]; do
                  case "$1" in
                      -h|--help) usage ;;
                      -*)
                          log_error "Unknown flag: $1"
                          exit 1
                          ;;
                      *)
                          log_error "Unexpected argument: $1"
                          exit 1
                          ;;
                  esac
              done
              ;;
          add|remove|info)
              while [[ $# -gt 0 ]]; do
                  case "$1" in
                      -y|--yes|--no-build)
                          parse_build_flag "$1"
                          shift
                          ;;
                      -h|--help) usage ;;
                      -*)
                          log_error "Unknown flag: $1"
                          exit 1
                          ;;
                      *)
                          NAMES+=("$1")
                          shift
                          ;;
                  esac
              done
              if [[ ''${#NAMES[@]} -eq 0 ]]; then
                  log_error "Missing name argument for: module $SUBCOMMAND"
                  exit 1
              fi
              if [[ "$SUBCOMMAND" == "info" ]] && [[ ''${#NAMES[@]} -ne 1 ]]; then
                  log_error "module info accepts exactly one name"
                  exit 1
              fi
              ;;
          -h|--help) usage ;;
          *)
              log_error "Unknown module subcommand: $SUBCOMMAND"
              echo "Valid subcommands: list, available, add, remove, info"
              exit 1
              ;;
      esac
  }

  # ----------------------------------------------------------------------------
  # Path helpers (layout-aware: monolith stages leaf edits then flushes)
  # ----------------------------------------------------------------------------

  _NCC_PKG_TMP=""
  _NCC_USER_TMPS=()

  _ncc_packages_flush() {
      if [[ -n "''${_NCC_PKG_TMP:-}" && -f "$_NCC_PKG_TMP" ]]; then
          ncc_write_module_config "core/base/packages" "$(cat "$_NCC_PKG_TMP")"
          rm -f "$_NCC_PKG_TMP"
          _NCC_PKG_TMP=""
      fi
      local entry
      for entry in "''${_NCC_USER_TMPS[@]:-}"; do
          [[ -z "$entry" ]] && continue
          local user="''${entry%%:*}"
          local tmp="''${entry#*:}"
          if [[ -f "$tmp" ]]; then
              ncc_write_module_config "users/$user" "$(cat "$tmp")"
              rm -f "$tmp"
          fi
      done
      _NCC_USER_TMPS=()
  }
  trap '_ncc_packages_flush' EXIT

  # Human-readable destination (monolith stages edits in /tmp until flush)
  config_display_path() {
      local path="$1"
      if [[ "$(ncc_detect_layout)" != "monolith" ]]; then
          echo "$path"
          return
      fi
      if [[ -n "''${_NCC_PKG_TMP:-}" && "$path" == "$_NCC_PKG_TMP" ]]; then
          echo "$MONOLITH_FILE (core.base.packages)"
          return
      fi
      local entry
      for entry in "''${_NCC_USER_TMPS[@]:-}"; do
          [[ -z "$entry" ]] && continue
          local user="''${entry%%:*}"
          local tmp="''${entry#*:}"
          if [[ "$path" == "$tmp" ]]; then
              echo "$MONOLITH_FILE (users.$user)"
              return
          fi
      done
      echo "$path"
  }

  resolve_hostname() {
      local h
      h=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
      [[ -n "$h" ]] && echo "$h" || echo "nixos"
  }

  # Flush staged config, warn that a rebuild is needed, then prompt like system-update
  prompt_rebuild_after_change() {
      local reason="$1"

      _ncc_packages_flush

      # Steam / Brave / gaming / common unfree need allowUnfree in system-manager
      local check_tokens="$reason $PACKAGE ''${NAMES[*]:-}"
      if echo "$check_tokens" | grep -Eqi '(^|[[:space:]/])(gaming|brave|steam|zoom|zoom-us|discord|spotify|vscode|google-chrome|chrome|nvidia|cuda|unrar|slack)([[:space:]/]|$)'; then
          local sm
          if sm=$(ncc_read_module_config "core/management/system-manager" 2>/dev/null); then
              if ! echo "$sm" | grep -qE 'allowUnfree[[:space:]]*=[[:space:]]*true'; then
                  sm=$(echo "$sm" | sed -E 's/allowUnfree[[:space:]]*=[[:space:]]*false[[:space:]]*;/allowUnfree = true;/')
                  if ! echo "$sm" | grep -qE 'allowUnfree[[:space:]]*=[[:space:]]*true'; then
                      sm=$(echo "$sm" | sed -E 's/(systemType[[:space:]]*=[[:space:]]*"[^"]*"[[:space:]]*;)/\1\n  allowUnfree = true;/')
                  fi
                  ncc_write_module_config "core/management/system-manager" "$sm"
                  log_info "Enabled allowUnfree (required by selected unfree packages)"
              fi
          fi
      fi

      log_warn "New build required to use package '$reason'"

      local hostname build_cmd
      hostname=$(resolve_hostname)
      build_cmd="sudo ncc system build switch --flake $NIXOS_DIR#$hostname"

      if [[ "$SKIP_BUILD_PROMPT" == true ]]; then
          log_info "Skipping build. You can manually run: $build_cmd"
          return 0
      fi

      if [[ "$AUTO_BUILD" == true ]]; then
          log_info "Building system configuration..."
          if sh -c "$build_cmd" 2>&1; then
              log_success "System successfully updated and rebuilt!"
          else
              log_error "Build/switch failed (exit $?). Retry: $build_cmd"
          fi
          return 0
      fi

      if [[ ! -t 0 ]]; then
          log_info "Non-interactive session — skipping build prompt."
          log_info "You can manually run: $build_cmd"
          return 0
      fi

      while true; do
          printf "Do you want to build and switch to the new configuration? (y/n): "
          read -r build_choice
          case "$build_choice" in
              y|Y)
                  log_info "Building system configuration..."
                  if sh -c "$build_cmd" 2>&1; then
                      log_success "System successfully updated and rebuilt!"
                  else
                      log_warn "Build/switch exited with code $?"
                      log_info "You can retry with: $build_cmd"
                  fi
                  break
                  ;;
              n|N)
                  log_info "Skipping build. You can manually run: $build_cmd"
                  break
                  ;;
              *)
                  log_error "Invalid choice, please enter y or n"
                  ;;
          esac
      done
  }

  get_user_config_path() {
      local user="$1"
      if [[ "$(ncc_detect_layout)" == "monolith" ]]; then
          local tmp
          tmp=$(mktemp --suffix=.nix)
          ncc_read_module_config "users/$user" > "$tmp"
          _NCC_USER_TMPS+=("$user:$tmp")
          echo "$tmp"
      else
          echo "$SYSTEM_CONFIG/users/$user/config.nix"
      fi
  }

  get_system_config_path() {
      if [[ "$(ncc_detect_layout)" == "monolith" ]]; then
          if [[ -z "$_NCC_PKG_TMP" ]]; then
              _NCC_PKG_TMP=$(mktemp --suffix=.nix)
              ncc_read_module_config "core/base/packages" > "$_NCC_PKG_TMP"
          fi
          echo "$_NCC_PKG_TMP"
      else
          echo "$SYSTEM_CONFIG/core/base/packages/config.nix"
      fi
  }

  get_modules_config_path() {
      get_system_config_path
  }

  get_sets_dir() {
      echo "$NIXOS_DIR/core/base/packages/components/sets"
  }

  get_recipes_dir() {
      echo "$NIXOS_DIR/core/base/packages/components/recipes"
  }

  get_user_presets_dir() {
      echo "$NIXOS_DIR/core/base/packages/components/user-presets"
  }

  # Resolve recipe or user-preset file (never mix folders)
  resolve_preset_file() {
      local name="$1"
      local f
      f="$(get_recipes_dir)/$name.nix"
      [[ -f "$f" ]] && { echo "$f"; return 0; }
      f="$(get_user_presets_dir)/$name.nix"
      [[ -f "$f" ]] && { echo "$f"; return 0; }
      return 1
  }

  get_metadata_path() {
      echo "$NIXOS_DIR/core/base/packages/lib/metadata.nix"
  }

  resolve_target_user() {
      if [[ -n "$TARGET_USER" ]]; then
          echo "$TARGET_USER"
      else
          whoami 2>/dev/null || echo "root"
      fi
  }

  config_exists() {
      [[ -f "$1" ]]
  }

  ensure_dir() {
      mkdir -p "$(dirname "$1")"
  }

  # ----------------------------------------------------------------------------
  # Single-package (nixpkgs) management — unchanged behavior
  # ----------------------------------------------------------------------------

  package_in_config() {
      local config_path="$1"
      local package="$2"
      grep -qE "\"$package\"|'$package'" "$config_path" 2>/dev/null
  }

  add_package() {
      local config_path="$1"
      local package="$2"
      local option_name="$3"

      if package_in_config "$config_path" "$package"; then
          log_warn "'$package' already in $option_name, skipping"
          return 0
      fi

      if ! config_exists "$config_path"; then
          ensure_dir "$config_path"
          printf '{\n  %s = [ "%s" ];\n}\n' "$option_name" "$package" > "$config_path"
          log_success "Created $(config_display_path "$config_path") with $option_name = [ \"$package\" ]"
          CONFIG_CHANGED=true
          return 0
      fi

      if grep -qE "^[[:space:]]*$option_name[[:space:]]*=" "$config_path" 2>/dev/null; then
          if grep -qE "^[[:space:]]*$option_name[[:space:]]*=[[:space:]]*\[[[:space:]]*\]" "$config_path" 2>/dev/null; then
              sed -i -E "s|^([[:space:]]*)$option_name([[:space:]]*=[[:space:]]*)\[[[:space:]]*\]|\1$option_name\2[ \"$package\" ]|" "$config_path"
          elif grep -qE "^[[:space:]]*$option_name[[:space:]]*=[[:space:]]*\[.*\][[:space:]]*;" "$config_path" 2>/dev/null; then
              sed -i -E "s|^([[:space:]]*$option_name[[:space:]]*=[[:space:]]*\[)(.*)(\][[:space:]]*;)|\1\2 \"$package\" \3|" "$config_path"
          else
              local temp_file
              temp_file=$(mktemp)
              local in_array=false
              local found_option=false

              while IFS= read -r line; do
                  if echo "$line" | grep -qE "^[[:space:]]*$option_name[[:space:]]*="; then
                      found_option=true
                      in_array=true
                      echo "$line" >> "$temp_file"
                  elif [[ "$found_option" == true ]] && [[ "$in_array" == true ]]; then
                      if echo "$line" | grep -qE "^[[:space:]]*\]"; then
                          printf '    "%s"\n' "$package" >> "$temp_file"
                          echo "$line" >> "$temp_file"
                          in_array=false
                          found_option=false
                      else
                          echo "$line" >> "$temp_file"
                      fi
                  else
                      echo "$line" >> "$temp_file"
                  fi
              done < "$config_path"

              mv "$temp_file" "$config_path"
          fi
      else
          # Insert the option before the final closing brace, or append
          if grep -qE "^\}[[:space:]]*$" "$config_path"; then
              sed -i -E "s|^\}[[:space:]]*$|  $option_name = [ \"$package\" ];\n}|" "$config_path"
          else
              printf '\n%s = [ "%s" ];\n' "$option_name" "$package" >> "$config_path"
          fi
      fi

      log_success "Added '$package' to $option_name in $(config_display_path "$config_path")"
      CONFIG_CHANGED=true
  }

  remove_package() {
      local config_path="$1"
      local package="$2"
      local option_name="$3"

      if ! config_exists "$config_path"; then
          log_error "Config file not found: $config_path"
          exit 1
      fi

      if ! package_in_config "$config_path" "$package"; then
          log_error "'$package' not found in $config_path"
          exit 1
      fi

      local temp_file
      temp_file=$(mktemp)
      local in_target=false
      local found_option=false

      while IFS= read -r line; do
          if echo "$line" | grep -qE "^[[:space:]]*$option_name[[:space:]]*="; then
              if echo "$line" | grep -qE "\".*$package.*\"|'.*$package.*'"; then
                  # Single-line array — strip the entry inline
                  local new_line
                  new_line=$(echo "$line" | sed -E "s|[[:space:]]*\"$package\"||g; s|[[:space:]]*'$package'||g")
                  echo "$new_line" >> "$temp_file"
              else
                  found_option=true
                  in_target=true
                  echo "$line" >> "$temp_file"
              fi
          elif [[ "$found_option" == true ]] && [[ "$in_target" == true ]]; then
              if echo "$line" | grep -qE "^[[:space:]]*\]"; then
                  in_target=false
                  found_option=false
                  echo "$line" >> "$temp_file"
              elif echo "$line" | grep -qE "^[[:space:]]*\"?$package\"?[[:space:]]*(,|$)"; then
                  :
              else
                  echo "$line" >> "$temp_file"
              fi
          else
              echo "$line" >> "$temp_file"
          fi
      done < "$config_path"

      mv "$temp_file" "$config_path"
      log_success "Removed '$package' from $option_name in $(config_display_path "$config_path")"
      CONFIG_CHANGED=true
  }

  list_packages_from_config() {
      local config_path="$1"
      local option_name="$2"
      local label="$3"

      if ! config_exists "$config_path"; then
          return 0
      fi

      local in_option=false
      local single_line_printed=false
      while IFS= read -r line; do
          if echo "$line" | grep -qE "^[[:space:]]*$option_name[[:space:]]*=[[:space:]]*\[.*\][[:space:]]*;"; then
              # Single-line array
              echo "$label:"
              local items
              items=$(echo "$line" | grep -oE "\"[^\"]+\"" | tr -d '"' || true)
              for item in $items; do
                  echo "  - $item"
              done
              single_line_printed=true
              echo ""
          elif echo "$line" | grep -qE "^[[:space:]]*$option_name[[:space:]]*="; then
              in_option=true
              echo "$label:"
          elif [[ "$in_option" == true ]]; then
              if echo "$line" | grep -qE "^[[:space:]]*\]"; then
                  in_option=false
                  echo ""
              else
                  local pkg
                  pkg=$(echo "$line" | sed -E "s/.*[\"']([^\"']+)[\"'].*/\1/")
                  if [[ -n "$pkg" ]] && [[ "$pkg" != "$option_name" ]]; then
                      echo "  - $pkg"
                  fi
              fi
          fi
      done < "$config_path"
  }

  # Print package names one per line (for --json)
  collect_package_names() {
      local config_path="$1"
      local option_name="$2"
      [[ -n "$config_path" ]] || return 0
      if ! config_exists "$config_path"; then
          return 0
      fi
      local in_option=false
      while IFS= read -r line; do
          if echo "$line" | grep -qE "^[[:space:]]*$option_name[[:space:]]*=[[:space:]]*\[.*\][[:space:]]*;"; then
              echo "$line" | grep -oE "\"[^\"]+\"" | tr -d '"' || true
          elif echo "$line" | grep -qE "^[[:space:]]*$option_name[[:space:]]*="; then
              in_option=true
          elif [[ "$in_option" == true ]]; then
              if echo "$line" | grep -qE "^[[:space:]]*\]"; then
                  in_option=false
              else
                  local pkg
                  pkg=$(echo "$line" | sed -E "s/.*[\"']([^\"']+)[\"'].*/\1/")
                  if [[ -n "$pkg" ]] && [[ "$pkg" != "$option_name" ]]; then
                      echo "$pkg"
                  fi
              fi
          fi
      done < "$config_path"
  }

  names_to_json_array() {
      local tmp
      tmp=$(mktemp)
      cat > "$tmp"
      if [[ ! -s "$tmp" ]]; then
          echo '[]'
          rm -f "$tmp"
          return 0
      fi
      ${pkgs.jq}/bin/jq -R -s -c 'split("\n") | map(select(length > 0))' < "$tmp"
      rm -f "$tmp"
  }

  # ----------------------------------------------------------------------------
  # Module / Preset support
  # ----------------------------------------------------------------------------

  is_preset_name() {
      local name="$1"
      resolve_preset_file "$name" >/dev/null
  }

  is_set_name() {
      local name="$1"
      local meta
      meta=$(get_metadata_path)
      [[ -f "$meta" ]] || return 1
      local result
      result=$(nix-instantiate --eval --strict -E "
        let m = import $meta;
            mods = m.modules or {};
        in if (mods.\"$name\" or null) != null then \"yes\" else \"no\"
      " 2>/dev/null | tr -d '\"' || echo "no")
      [[ "$result" == "yes" ]]
  }

  # Echo (newline-separated) the modules a system recipe contains
  preset_modules() {
      local name="$1"
      local preset_file
      preset_file="$(resolve_preset_file "$name")" || return 0
      nix-instantiate --eval --strict --json -E "
        let p = import $preset_file; in p.modules or []
      " 2>/dev/null | jq -r '.[]' 2>/dev/null || true
  }

  preset_packages() {
      local name="$1"
      local preset_file
      preset_file="$(resolve_preset_file "$name")" || return 0
      nix-instantiate --eval --strict --json -E "
        let p = import $preset_file; in p.packages or []
      " 2>/dev/null | jq -r '.[]' 2>/dev/null || true
  }

  # system (recipe) | user (user-preset) — derived from which folder / fields
  preset_scope() {
      local name="$1"
      local preset_file recipes_dir
      preset_file="$(resolve_preset_file "$name")" || { echo "system"; return 0; }
      recipes_dir=$(get_recipes_dir)
      if [[ "$preset_file" == "$recipes_dir"/* ]]; then
          echo "system"
          return 0
      fi
      echo "user"
  }

  # Echo description for a recipe / user-preset
  preset_description() {
      local name="$1"
      local preset_file
      preset_file="$(resolve_preset_file "$name")" || return 0
      nix-instantiate --eval --strict --json -E "
        let p = import $preset_file; in p.description or \"\"
      " 2>/dev/null | jq -r . 2>/dev/null || true
  }

  # Echo description for a set (from metadata.nix)
  set_description() {
      local name="$1"
      local meta
      meta=$(get_metadata_path)
      [[ -f "$meta" ]] || return 0
      nix-instantiate --eval --strict --json -E "
        let m = import $meta;
            mods = m.modules or {};
            entry = mods.\"$name\" or {};
        in entry.description or \"\"
      " 2>/dev/null | jq -r . 2>/dev/null || true
  }

  # Echo systemTypes for a set
  set_system_types() {
      local name="$1"
      local meta
      meta=$(get_metadata_path)
      [[ -f "$meta" ]] || return 0
      nix-instantiate --eval --strict --json -E "
        let m = import $meta;
            mods = m.modules or {};
            entry = mods.\"$name\" or {};
        in entry.systemTypes or []
      " 2>/dev/null | jq -r 'join(", ")' 2>/dev/null || true
  }

  # Expand a name to one or more set names (one per line)
  # - If preset: emit its module list
  # - Else if set: emit name as-is (remap deprecated aliases)
  # - Else: emit nothing and return 1
  expand_name() {
      local name="$1"
      if is_preset_name "$name"; then
          preset_modules "$name"
          return 0
      fi
      # Deprecated aliases
      if [[ "$name" == "game-dev" ]]; then
          name="game-engines"
      fi
      if is_set_name "$name"; then
          echo "$name"
          return 0
      fi
      return 1
  }

  # ----- Store: search / resolve / try / categories -----

  _catalog_ok() {
      if [[ ! -f "$CATALOG_JSON" ]]; then
          log_error "Catalog not found: $CATALOG_JSON"
          exit 1
      fi
  }

  # Score intents for QUERY; emit ranked JSON array of intent objects.
  _intent_matches_json() {
      local q
      q=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      "$JQ" -c --arg q "$q" '
        def norm: ascii_downcase | gsub("^\\s+|\\s+$";"");
        def score($q; $it):
          (($it.aliases // []) + [$it.id, $it.title]
            | map(norm) | map(select(length > 0))) as $names
          | if ($names | map(select(. == $q)) | length) > 0 then 100
            elif ($names | map(select(startswith($q))) | length) > 0 then 80
            elif ($q | length) >= 3
                 and ($names
                      | map(select(. as $n | ($n | length) >= 3 and ($q | startswith($n))))
                      | length) > 0
                 then 70
            elif ($names | map(select(contains($q))) | length) > 0 then 60
            elif (($it.description // "") | norm | contains($q)) then 40
            elif (($it.category // "") | norm) == $q then 30
            else 0 end;
        [.intents[] | . as $it | (score($q; $it)) as $s | select($s > 0) | $it + {_score: $s}]
        | sort_by(-._score, .title)
      ' "$CATALOG_JSON"
  }

  cmd_categories() {
      _catalog_ok
      if [[ "$JSON_OUT" == true ]]; then
          "$JQ" -c '{categories: (.categories // [])}' "$CATALOG_JSON"
          return 0
      fi
      echo "=== Store categories ==="
      "$JQ" -r '.categories[]? | "  \(.id)\t\(.title)\t\(.description // "")"' "$CATALOG_JSON"
  }

  cmd_search() {
      _catalog_ok
      local matches
      matches=$(_intent_matches_json "$QUERY")
      if [[ "$JSON_OUT" == true ]]; then
          "$JQ" -nc --arg q "$QUERY" --argjson matches "$matches" \
            '{query:$q, matches:$matches}'
          return 0
      fi
      local count
      count=$("$JQ" -r 'length' <<<"$matches")
      echo "=== Search: $QUERY ($count hit(s)) ==="
      if [[ "$count" -eq 0 ]]; then
          echo "  (no curated intent — try exact nixpkgs attr with: $SCRIPT_NAME add <attr>)"
          return 0
      fi
      "$JQ" -r '.[] | "  \(.title)  [\(.kind)/\(.scope)]  \(.description // "")\n    id=\(.id)  action=\(if .kind == "attr" then ("add " + (.attr // "?")) elif .module then ("module add " + .module) else "guided" end)\(if .tryable then "  (tryable)" else "" end)"' <<<"$matches"
  }

  cmd_resolve() {
      _catalog_ok
      local matches best
      matches=$(_intent_matches_json "$QUERY")
      best=$("$JQ" -c '.[0] // null' <<<"$matches")
      if [[ "$best" == "null" ]]; then
          if [[ "$JSON_OUT" == true ]]; then
              "$JQ" -nc --arg q "$QUERY" \
                '{query:$q, match:null, action:{type:"unknown", argv:[], message:"No curated intent; use add <nixpkgs-attr> if you know the attribute name."}}'
          else
              log_warn "No curated intent for: $QUERY"
              echo "Hint: $SCRIPT_NAME search \"$QUERY\"  or  $SCRIPT_NAME add <nixpkgs-attr>"
          fi
          return 0
      fi

      local action_json
      action_json=$("$JQ" -c '
        . as $m
        | if $m.kind == "attr" and ($m.attr != null) then
            {type:"add", scope:"user", attr:$m.attr, module:null, argv:["add", $m.attr], tryable:($m.tryable == true), requiresAdmin:($m.requiresAdmin == true)}
          elif $m.kind == "guided" then
            {type:"guided", scope:$m.scope, attr:null, module:$m.module,
             argv:(if $m.module then ["module","add",$m.module] else [] end),
             tryable:false, requiresAdmin:($m.requiresAdmin == true),
             message:($m.notes // $m.description // "")}
          elif ($m.kind == "set" or $m.kind == "recipe" or $m.kind == "user-preset") and ($m.module != null) then
            {type:"module-add", scope:$m.scope, attr:$m.attr, module:$m.module,
             argv:["module","add",$m.module], tryable:false, requiresAdmin:($m.requiresAdmin == true)}
          else
            {type:"unknown", scope:$m.scope, attr:$m.attr, module:$m.module, argv:[], tryable:false, requiresAdmin:($m.requiresAdmin == true)}
          end
      ' <<<"$best")

      if [[ "$JSON_OUT" == true ]]; then
          "$JQ" -nc --arg q "$QUERY" --argjson match "$best" --argjson action "$action_json" \
            '{query:$q, match:$match, action:$action}'
          return 0
      fi
      echo "=== Resolve: $QUERY ==="
      "$JQ" -r '"Title: \(.title)\nKind:  \(.kind) / scope=\(.scope)\nDesc:  \(.description // "")\nNotes: \(.notes // "")"' <<<"$best"
      echo ""
      "$JQ" -r '
        "Action: \(.type)"
        + (if .attr then "\nAttr:   \(.attr)" else "" end)
        + (if .module then "\nModule: \(.module)" else "" end)
        + "\nCLI:    ncc packages " + (.argv | join(" "))
        + (if .tryable then "\nTry:    ncc packages try " + (.attr // "") else "" end)
        + (if .requiresAdmin then "\nNeeds:  administrator" else "\nNeeds:  your user account" end)
        + (if .message then "\n\(.message)" else "" end)
      ' <<<"$action_json"
  }

  cmd_try() {
      local attr="$PACKAGE"
      if [[ ! "$attr" =~ ^[a-zA-Z0-9][a-zA-Z0-9._+-]*$ ]]; then
          log_error "Invalid package attribute: $attr"
          exit 1
      fi
      # If query looks like a product name, resolve to attr when tryable
      if [[ -f "$CATALOG_JSON" ]]; then
          local resolved
          resolved=$(_intent_matches_json "$QUERY")
          local try_attr
          try_attr=$("$JQ" -r '
            [.[] | select(.tryable == true and .attr != null)] | .[0].attr // empty
          ' <<<"$resolved")
          if [[ -n "$try_attr" ]]; then
              attr="$try_attr"
          elif "$JQ" -e --arg a "$attr" '
              [.intents[] | select((.attr == $a) and (.tryable == false))] | length > 0
            ' "$CATALOG_JSON" >/dev/null 2>&1; then
              log_error "'$attr' is not safe to try in nix-shell (needs a module/rebuild)."
              echo "Hint: $SCRIPT_NAME resolve \"$QUERY\""
              exit 1
          fi
      fi
      log_info "Trying $attr in a temporary nix-shell (no config write)…"
      log_info "Exit the shell when done. To install permanently: $SCRIPT_NAME add $attr"
      exec "$NIX_SHELL_BIN" -p "$attr"
  }

  # ----- module subcommands -----

  module_list() {
      local cfg
      cfg=$(get_modules_config_path)
      echo "=== Active packageModules ==="
      if [[ ! -f "$cfg" ]]; then
          echo "  (config file does not exist yet: $cfg)"
          return 0
      fi
      list_packages_from_config "$cfg" "packageModules" "packageModules"
  }

  module_available() {
      local sets_dir recipes_dir user_presets_dir
      sets_dir=$(get_sets_dir)
      recipes_dir=$(get_recipes_dir)
      user_presets_dir=$(get_user_presets_dir)

      echo "=== Available sets (individual modules) ==="
      if [[ -d "$sets_dir" ]]; then
          for f in "$sets_dir"/*.nix; do
              [[ -e "$f" ]] || continue
              local name
              name=$(basename "$f" .nix)
              local desc
              desc=$(set_description "$name" || true)
              if [[ -n "$desc" ]]; then
                  printf "  %-22s %s\n" "$name" "$desc"
              else
                  printf "  %s\n" "$name"
              fi
          done
      else
          echo "  (sets directory not found: $sets_dir)"
      fi

      echo ""
      echo "=== System recipes (→ packageModules) ==="
      if [[ -d "$recipes_dir" ]]; then
          for f in "$recipes_dir"/*.nix; do
              [[ -e "$f" ]] || continue
              local name desc
              name=$(basename "$f" .nix)
              desc=$(preset_description "$name" || true)
              if [[ -n "$desc" ]]; then
                  printf "  %-22s [system] %s\n" "$name" "$desc"
              else
                  printf "  %-22s [system]\n" "$name"
              fi
          done
      else
          echo "  (recipes directory not found: $recipes_dir)"
      fi

      echo ""
      echo "=== User presets (→ userPackages) ==="
      if [[ -d "$user_presets_dir" ]]; then
          for f in "$user_presets_dir"/*.nix; do
              [[ -e "$f" ]] || continue
              local name desc
              name=$(basename "$f" .nix)
              desc=$(preset_description "$name" || true)
              if [[ -n "$desc" ]]; then
                  printf "  %-22s [user] %s\n" "$name" "$desc"
              else
                  printf "  %-22s [user]\n" "$name"
              fi
          done
      else
          echo "  (user-presets directory not found: $user_presets_dir)"
      fi
  }

  module_info() {
      local name="$1"
      if is_preset_name "$name"; then
          local scope
          scope=$(preset_scope "$name")
          echo "$name (preset, scope=$scope)"
          local desc
          desc=$(preset_description "$name" || true)
          [[ -n "$desc" ]] && echo "  Description: $desc"
          if [[ "$scope" == "user" ]]; then
              echo "  Packages (→ users.<you>.userPackages):"
              local pkg
              while IFS= read -r pkg; do
                  [[ -z "$pkg" ]] && continue
                  printf "    - %s\n" "$pkg"
              done < <(preset_packages "$name")
          else
              echo "  Modules (→ packageModules):"
              local m
              while IFS= read -r m; do
                  [[ -z "$m" ]] && continue
                  local md
                  md=$(set_description "$m" || true)
                  if [[ -n "$md" ]]; then
                      printf "    - %-20s %s\n" "$m" "$md"
                  else
                      printf "    - %s\n" "$m"
                  fi
              done < <(preset_modules "$name")
          fi
          return 0
      fi
      if is_set_name "$name"; then
          echo "$name (set)"
          local desc types
          desc=$(set_description "$name" || true)
          types=$(set_system_types "$name" || true)
          [[ -n "$desc" ]] && echo "  Description: $desc"
          [[ -n "$types" ]] && echo "  System types: $types"
          return 0
      fi
      log_error "Unknown name: '$name' (not a known set or preset)"
      echo "Hint: try '$SCRIPT_NAME module available' to see valid names" >&2
      exit 1
  }

  module_add_user_preset() {
      local preset="$1"
      local target_user pkg
      target_user=$(resolve_target_user)
      log_info "User preset '$preset' → users.$target_user.userPackages"
      local count=0
      while IFS= read -r pkg; do
          [[ -z "$pkg" ]] && continue
          PACKAGE="$pkg"
          count=$((count + 1))
          if command -v ncc-priv-run >/dev/null 2>&1; then
              ncc-priv-run user-pkg add "$PACKAGE" --user "$target_user"
              CONFIG_CHANGED=false
          elif [[ "$(id -u)" -eq 0 ]]; then
              add_package "$(get_user_config_path "$target_user")" "$PACKAGE" "userPackages"
          else
              log_error "Cannot write user packages (ncc-priv-run missing; rebuild NCC)"
              exit 1
          fi
      done < <(preset_packages "$preset")
      if [[ "$count" -eq 0 ]]; then
          log_error "User preset '$preset' has no packages = [ … ]"
          exit 1
      fi
      log_success "User preset '$preset' applied for $target_user ($count packages)"
  }

  module_remove_user_preset() {
      local preset="$1"
      local target_user pkg
      target_user=$(resolve_target_user)
      log_info "Removing user preset '$preset' from users.$target_user"
      while IFS= read -r pkg; do
          [[ -z "$pkg" ]] && continue
          PACKAGE="$pkg"
          if command -v ncc-priv-run >/dev/null 2>&1; then
              ncc-priv-run user-pkg remove "$PACKAGE" --user "$target_user" || log_warn "skip $PACKAGE"
              CONFIG_CHANGED=false
          elif [[ "$(id -u)" -eq 0 ]]; then
              remove_package "$(get_user_config_path "$target_user")" "$PACKAGE" "userPackages" || true
          else
              log_error "Cannot write user packages (ncc-priv-run missing; rebuild NCC)"
              exit 1
          fi
      done < <(preset_packages "$preset")
      log_success "User preset '$preset' packages removed for $target_user"
  }

  module_add() {
      local arg
      local system_names=()
      for arg in "$@"; do
          if is_preset_name "$arg" && [[ "$(preset_scope "$arg")" == "user" ]]; then
              module_add_user_preset "$arg"
          else
              system_names+=("$arg")
          fi
      done
      if [[ ''${#system_names[@]} -eq 0 ]]; then
          return 0
      fi

      if [[ "$(id -u)" -ne 0 ]]; then
          log_error "Changing system package modules/sets requires administrator rights"
          exit 1
      fi
      local cfg
      cfg=$(get_modules_config_path)

      local resolved=()
      for arg in "''${system_names[@]}"; do
          local expanded
          if ! expanded=$(expand_name "$arg"); then
              log_error "Unknown name: '$arg' (not a known set or system preset)"
              echo "Hint: try '$SCRIPT_NAME module available' to see valid names" >&2
              exit 1
          fi
          local line
          while IFS= read -r line; do
              [[ -z "$line" ]] && continue
              if ! is_set_name "$line"; then
                  log_error "Preset '$arg' references unknown set '$line'"
                  exit 1
              fi
              resolved+=("$line")
          done <<< "$expanded"
          if is_preset_name "$arg"; then
              log_info "Preset '$arg' expands to: $(preset_modules "$arg" | tr '\n' ' ')"
          fi
      done

      local set_name
      for set_name in "''${resolved[@]}"; do
          add_package "$cfg" "$set_name" "packageModules"
      done
  }

  module_remove() {
      local arg
      local system_names=()
      for arg in "$@"; do
          if is_preset_name "$arg" && [[ "$(preset_scope "$arg")" == "user" ]]; then
              module_remove_user_preset "$arg"
          else
              system_names+=("$arg")
          fi
      done
      if [[ ''${#system_names[@]} -eq 0 ]]; then
          return 0
      fi

      if [[ "$(id -u)" -ne 0 ]]; then
          log_error "Changing system package modules/sets requires administrator rights"
          exit 1
      fi
      local cfg
      cfg=$(get_modules_config_path)
      if [[ ! -f "$cfg" ]]; then
          log_error "Config file not found: $cfg"
          exit 1
      fi
      for arg in "''${system_names[@]}"; do
          if is_preset_name "$arg"; then
              log_info "Preset '$arg' will remove sets: $(preset_modules "$arg" | tr '\n' ' ')"
              local m
              while IFS= read -r m; do
                  [[ -z "$m" ]] && continue
                  if package_in_config "$cfg" "$m"; then
                      remove_package "$cfg" "$m" "packageModules"
                  else
                      log_warn "'$m' not in packageModules, skipping"
                  fi
              done < <(preset_modules "$arg")
          else
              if package_in_config "$cfg" "$arg"; then
                  remove_package "$cfg" "$arg" "packageModules"
              else
                  log_warn "'$arg' not in packageModules, skipping"
              fi
          fi
      done
  }

  # ----------------------------------------------------------------------------
  # main
  # ----------------------------------------------------------------------------

  main() {
      parse_args "$@"

      case "$COMMAND" in
          add)
              local target_user pkg
              target_user=$(resolve_target_user)
              for pkg in "''${PACKAGES[@]}"; do
                  PACKAGE="$pkg"
                  if [[ "$TARGET_SYSTEM" == true ]]; then
                      if [[ "$(id -u)" -ne 0 ]]; then
                          log_error "System packages require administrator rights"
                          exit 1
                      fi
                      add_package "$(get_system_config_path)" "$PACKAGE" "systemPackages"
                  else
                          if command -v ncc-priv-run >/dev/null 2>&1; then
                          local args=(user-pkg add "$PACKAGE" --user "$target_user")
                          local last="''${PACKAGES[-1]}"
                          [[ "$AUTO_BUILD" == true && "$pkg" == "$last" ]] && args+=(--rebuild)
                          ncc-priv-run "''${args[@]}"
                          CONFIG_CHANGED=false
                      elif [[ "$(id -u)" -eq 0 ]]; then
                          add_package "$(get_user_config_path "$target_user")" "$PACKAGE" "userPackages"
                      else
                          log_error "Cannot write user packages (ncc-priv-run missing; rebuild NCC)"
                          exit 1
                      fi
                  fi
              done
              ;;

          remove)
              local target_user pkg
              target_user=$(resolve_target_user)
              for pkg in "''${PACKAGES[@]}"; do
                  PACKAGE="$pkg"
                  if [[ "$TARGET_SYSTEM" == true ]]; then
                      if [[ "$(id -u)" -ne 0 ]]; then
                          log_error "System packages require administrator rights"
                          exit 1
                      fi
                      remove_package "$(get_system_config_path)" "$PACKAGE" "systemPackages"
                  else
                      if command -v ncc-priv-run >/dev/null 2>&1; then
                          local args=(user-pkg remove "$PACKAGE" --user "$target_user")
                          local last="''${PACKAGES[-1]}"
                          [[ "$AUTO_BUILD" == true && "$pkg" == "$last" ]] && args+=(--rebuild)
                          ncc-priv-run "''${args[@]}"
                          CONFIG_CHANGED=false
                      elif [[ "$(id -u)" -eq 0 ]]; then
                          remove_package "$(get_user_config_path "$target_user")" "$PACKAGE" "userPackages"
                      else
                          log_error "Cannot write user packages (ncc-priv-run missing; rebuild NCC)"
                          exit 1
                      fi
                  fi
              done
              ;;

          list)
              if [[ "$JSON_OUT" == true ]]; then
                  local target_user user_json system_json
                  target_user=$(resolve_target_user)
                  if [[ -f "$MONOLITH_FILE" ]]; then
                      # Prefer monolith eval: mine = userPackages ++ environment.systemPackages
                      local raw
                      raw=$("$NIX_INSTANTIATE_BIN" --eval --strict --json -E "
                        let
                          c = import $MONOLITH_FILE;
                          u = c.users.\"$target_user\" or {};
                          up = if builtins.isList (u.userPackages or null) then u.userPackages else [];
                          ep = if builtins.isList (u.environment.systemPackages or null) then u.environment.systemPackages else [];
                          sys = if builtins.isList (c.core.base.packages.systemPackages or null) then c.core.base.packages.systemPackages else [];
                        in {
                          user = \"$target_user\";
                          mine = up ++ ep;
                          system = sys;
                        }
                      " 2>/dev/null) || raw=""
                      if [[ -n "$raw" ]] && "$JQ" -e . >/dev/null 2>&1 <<<"$raw"; then
                          if [[ "$TARGET_SYSTEM" == true ]]; then
                              echo "$raw" | "$JQ" -c '{system}'
                          else
                              echo "$raw" | "$JQ" -c .
                          fi
                      else
                          user_json='[]'
                          system_json=$(collect_package_names "$(get_system_config_path)" "systemPackages" | names_to_json_array)
                          "$JQ" -nc --arg user "$target_user" --argjson mine "$user_json" --argjson system "$system_json" \
                            '{user:$user, mine:$mine, system:$system}'
                      fi
                  else
                      if [[ "$TARGET_SYSTEM" == true ]]; then
                          system_json=$(collect_package_names "$(get_system_config_path)" "systemPackages" | names_to_json_array)
                          "$JQ" -nc --argjson system "$system_json" '{system:$system}'
                      else
                          user_json=$(collect_package_names "$(get_user_config_path "$target_user")" "userPackages" | names_to_json_array)
                          # also leaf environment.systemPackages via facade read + grep is hard; try path
                          local leaf_env
                          leaf_env=$(collect_package_names "$(get_user_config_path "$target_user")" "systemPackages" | names_to_json_array)
                          user_json=$("$JQ" -nc --argjson a "$user_json" --argjson b "$leaf_env" '$a + $b | unique')
                          system_json=$(collect_package_names "$(get_system_config_path)" "systemPackages" | names_to_json_array)
                          "$JQ" -nc --arg user "$target_user" --argjson mine "$user_json" --argjson system "$system_json" \
                            '{user:$user, mine:$mine, system:$system}'
                      fi
                  fi
              else
                  echo "=== NCC Package Configuration ==="
                  echo ""
                  if [[ "$TARGET_SYSTEM" == true ]]; then
                      list_packages_from_config "$(get_system_config_path)" "systemPackages" "System Packages"
                  else
                      local target_user
                      target_user=$(resolve_target_user)
                      local user_config_path
                      user_config_path=$(get_user_config_path "$target_user")
                      list_packages_from_config "$user_config_path" "userPackages" "User Packages ($target_user)"
                      list_packages_from_config "$user_config_path" "systemPackages" "User environment.systemPackages ($target_user)"
                      list_packages_from_config "$(get_system_config_path)" "systemPackages" "System Packages"
                  fi
              fi
              ;;

          search)
              cmd_search
              ;;
          resolve)
              cmd_resolve
              ;;
          try)
              cmd_try
              ;;
          categories)
              cmd_categories
              ;;

          module)
              case "$SUBCOMMAND" in
                  list)      module_list ;;
                  available) module_available ;;
                  add)       module_add "''${NAMES[@]}" ;;
                  remove)    module_remove "''${NAMES[@]}" ;;
                  info)      module_info "''${NAMES[0]}" ;;
              esac
              ;;
      esac

      if [[ "$CONFIG_CHANGED" == true ]]; then
          local reason
          case "$COMMAND" in
              add|remove)
                  reason="$PACKAGE"
                  ;;
              module)
                  reason="''${NAMES[*]}"
                  ;;
              *)
                  reason="the updated packages"
                  ;;
          esac
          prompt_rebuild_after_change "$reason"
      fi
  }

  main "$@"
''
