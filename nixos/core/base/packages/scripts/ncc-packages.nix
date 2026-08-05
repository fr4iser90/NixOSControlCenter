{ pkgs }:

let
  facade = import ../../../management/system-manager/lib/config-facade.nix { inherit pkgs; };
in
pkgs.writeShellScriptBin "ncc-packages" ''
  SCRIPT_NAME="ncc-packages"
  VERSION="2.0.0"

  set -euo pipefail

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  SYSTEM_CONFIG="$NIXOS_DIR/systemConfig"
  MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  # Allow NIXOS_DIR override after preamble
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$SYSTEM_CONFIG"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

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
  NAMES=()

  usage() {
      cat << EOF
  $SCRIPT_NAME - Package Management CLI

  Usage:
    Single packages (nixpkgs):
      $SCRIPT_NAME add <package> [--user <name>] [--system]
      $SCRIPT_NAME remove <package> [--user <name>] [--system]
      $SCRIPT_NAME list [--system]

    Module sets and presets (packageModules):
      $SCRIPT_NAME module list                 List active packageModules
      $SCRIPT_NAME module available            Show all available sets and presets
      $SCRIPT_NAME module add <name>...        Add set(s) and/or preset(s)
      $SCRIPT_NAME module remove <name>...     Remove set(s)
      $SCRIPT_NAME module info <name>          Show details for a set or preset

  Flags (single packages):
    --system       Target systemPackages (global, all users)
    --user <name>  Target a specific user's userPackages
    -h, --help     Show this help message
    -v, --version  Show version

  Defaults:
    Without flags, single-package operations target the current user's userPackages.
    Module operations edit core.base.packages via config-facade
    (monolith: systemConfig.nix | split: systemConfig/core/base/packages/config.nix).

  Layout:
    ncc-config-layout detect
    ncc system config-layout convert --to monolith|split

  Examples:
    $SCRIPT_NAME add vscode                          Add vscode to current user
    $SCRIPT_NAME add nginx --system                  Add nginx to systemPackages
    $SCRIPT_NAME list                                List all single packages

    $SCRIPT_NAME module available                    Show what can be enabled
    $SCRIPT_NAME module add gaming                   Enable single set
    $SCRIPT_NAME module add gaming-desktop           Apply preset (expands to 4 sets)
    $SCRIPT_NAME module add gaming streaming         Add multiple sets at once
    $SCRIPT_NAME module remove emulation             Remove a single set
    $SCRIPT_NAME module info gaming-desktop          Show what a preset contains

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
          module)
              parse_module_args "$@"
              ;;
          -h|--help) usage ;;
          -v|--version) version ;;
          *)
              log_error "Unknown command: $COMMAND"
              echo "Valid commands: add, remove, list, module"
              exit 1
              ;;
      esac
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
              -h|--help) usage ;;
              -v|--version) version ;;
              -*)
                  log_error "Unknown flag: $1"
                  exit 1
                  ;;
              *)
                  if [[ -z "$PACKAGE" ]]; then
                      PACKAGE="$1"
                  else
                      log_error "Unexpected argument: $1"
                      exit 1
                  fi
                  shift
                  ;;
          esac
      done

      if [[ "$COMMAND" != "list" ]] && [[ -z "$PACKAGE" ]]; then
          log_error "Missing package name. Usage: $SCRIPT_NAME $COMMAND <package> [flags]"
          exit 1
      fi
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
          list|available) ;;
          add|remove|info)
              if [[ $# -eq 0 ]]; then
                  log_error "Missing name argument for: module $SUBCOMMAND"
                  exit 1
              fi
              while [[ $# -gt 0 ]]; do
                  case "$1" in
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

  get_presets_dir() {
      echo "$NIXOS_DIR/core/base/packages/components/presets"
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
          log_success "Created $config_path with $option_name = [ \"$package\" ]"
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

      log_success "Added '$package' to $option_name in $config_path"
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
      log_success "Removed '$package' from $option_name in $config_path"
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

  # ----------------------------------------------------------------------------
  # Module / Preset support
  # ----------------------------------------------------------------------------

  is_preset_name() {
      local name="$1"
      [[ -f "$(get_presets_dir)/$name.nix" ]]
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

  # Echo (newline-separated) the modules a preset contains
  preset_modules() {
      local name="$1"
      local preset_file
      preset_file="$(get_presets_dir)/$name.nix"
      [[ -f "$preset_file" ]] || return 0
      nix-instantiate --eval --strict --json -E "
        let p = import $preset_file; in p.modules or []
      " 2>/dev/null | jq -r '.[]' 2>/dev/null || true
  }

  # Echo description for a preset
  preset_description() {
      local name="$1"
      local preset_file
      preset_file="$(get_presets_dir)/$name.nix"
      [[ -f "$preset_file" ]] || return 0
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
  # - Else if set: emit name as-is
  # - Else: emit nothing and return 1
  expand_name() {
      local name="$1"
      if is_preset_name "$name"; then
          preset_modules "$name"
          return 0
      fi
      if is_set_name "$name"; then
          echo "$name"
          return 0
      fi
      return 1
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
      local sets_dir presets_dir
      sets_dir=$(get_sets_dir)
      presets_dir=$(get_presets_dir)

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
      echo "=== Available presets (bundles of sets) ==="
      if [[ -d "$presets_dir" ]]; then
          for f in "$presets_dir"/*.nix; do
              [[ -e "$f" ]] || continue
              local name
              name=$(basename "$f" .nix)
              local desc
              desc=$(preset_description "$name" || true)
              if [[ -n "$desc" ]]; then
                  printf "  %-22s %s\n" "$name" "$desc"
              else
                  printf "  %s\n" "$name"
              fi
          done
      else
          echo "  (presets directory not found: $presets_dir)"
      fi
  }

  module_info() {
      local name="$1"
      if is_preset_name "$name"; then
          echo "$name (preset)"
          local desc
          desc=$(preset_description "$name" || true)
          [[ -n "$desc" ]] && echo "  Description: $desc"
          echo "  Modules:"
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

  module_add() {
      local cfg
      cfg=$(get_modules_config_path)

      # First pass: validate everything and collect resolved sets
      local resolved=()
      local arg
      for arg in "$@"; do
          local expanded
          if ! expanded=$(expand_name "$arg"); then
              log_error "Unknown name: '$arg' (not a known set or preset)"
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

      # Second pass: add each resolved set (skipping duplicates)
      local set_name
      for set_name in "''${resolved[@]}"; do
          add_package "$cfg" "$set_name" "packageModules"
      done
  }

  module_remove() {
      local cfg
      cfg=$(get_modules_config_path)
      if [[ ! -f "$cfg" ]]; then
          log_error "Config file not found: $cfg"
          exit 1
      fi
      local arg
      for arg in "$@"; do
          if is_preset_name "$arg"; then
              # Preset: remove every module it contains
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
              local target_user
              target_user=$(resolve_target_user)
              if [[ "$TARGET_SYSTEM" == true ]]; then
                  add_package "$(get_system_config_path)" "$PACKAGE" "systemPackages"
              else
                  add_package "$(get_user_config_path "$target_user")" "$PACKAGE" "userPackages"
              fi
              ;;

          remove)
              local target_user
              target_user=$(resolve_target_user)
              if [[ "$TARGET_SYSTEM" == true ]]; then
                  remove_package "$(get_system_config_path)" "$PACKAGE" "systemPackages"
              else
                  remove_package "$(get_user_config_path "$target_user")" "$PACKAGE" "userPackages"
              fi
              ;;

          list)
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
                  local central_user_config="$SYSTEM_CONFIG/core/base/user/config.nix"
                  if config_exists "$central_user_config" && ! config_exists "$user_config_path"; then
                      list_packages_from_config "$central_user_config" "userPackages" "User Packages (central, $target_user)"
                  fi
                  list_packages_from_config "$(get_system_config_path)" "systemPackages" "System Packages"
              fi
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
  }

  main "$@"
''
