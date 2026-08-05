{ pkgs, lib, getModuleApi, ... }:

let
  formatter = getModuleApi "cli-formatter";
  discovery = import ../../../module-manager/lib/discovery.nix { inherit lib; };
  convertLib = ../../lib/layout-convert.nix;

  # Module paths as newline-separated list (no JSON)
  modulePaths = map (m: lib.replaceStrings [ "." ] [ "/" ] m.configPath) discovery.discoverAllModules;
  modulePathsText = lib.concatStringsSep "\n" modulePaths;

  convertScript = pkgs.writeShellScriptBin "ncc-config-layout" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    NIXOS_CONFIG_DIR="''${NIXOS_CONFIG_DIR:-/etc/nixos}"
    MONOLITH_FILE="$NIXOS_CONFIG_DIR/systemConfig.nix"
    CONFIGS_DIR="$NIXOS_CONFIG_DIR/systemConfig"
    NIX_BIN="${pkgs.nix}/bin/nix"
    NIX_INSTANTIATE="${pkgs.nix}/bin/nix-instantiate"
    CONVERT_LIB="${convertLib}"
    FIND_BIN="${pkgs.findutils}/bin/find"
    MODULE_PATHS_FILE=$(mktemp)
    cat > "$MODULE_PATHS_FILE" <<'EOF'
${modulePathsText}
EOF
    trap 'rm -f "$MODULE_PATHS_FILE"' EXIT

    usage() {
      cat <<EOF
ncc-config-layout — detect or convert systemConfig layout (v2)

Usage:
  ncc-config-layout detect
  ncc-config-layout convert --to monolith [--force]
  ncc-config-layout convert --to split [--force]

Layouts:
  monolith  $MONOLITH_FILE (nested .nix attrset)
  split     $CONFIGS_DIR/**/config.nix

Convert is pure Nix (import + toPretty). No JSON config files are written.
EOF
    }

    has_split_configs() {
      [[ -d "$CONFIGS_DIR" ]] || return 1
      "$FIND_BIN" "$CONFIGS_DIR" -name 'config.nix' -type f 2>/dev/null | head -1 | grep -q .
    }

    detect_layout() {
      local has_mono=false has_split=false
      [[ -f "$MONOLITH_FILE" ]] && has_mono=true
      has_split_configs && has_split=true

      if $has_mono && ! $has_split; then echo "monolith"; return; fi
      if $has_split && ! $has_mono; then echo "split"; return; fi
      if $has_mono && $has_split; then
        local layout
        layout=$("$NIX_INSTANTIATE" --eval --strict -E \
          "let c = import $MONOLITH_FILE; in c.core.management.system-manager.layout or c.layout or \"monolith\"" \
          2>/dev/null | tr -d '"') || layout="monolith"
        echo "''${layout:-monolith}"
        return
      fi
      echo "none"
    }

    backup_tree() {
      local stamp backup_root
      stamp=$(date +%Y%m%d-%H%M%S)
      backup_root="/var/backup/nixos/systemConfig-layout-$stamp"
      mkdir -p "$backup_root"
      [[ -f "$MONOLITH_FILE" ]] && cp -a "$MONOLITH_FILE" "$backup_root/" || true
      [[ -d "$CONFIGS_DIR" ]] && cp -a "$CONFIGS_DIR" "$backup_root/systemConfig" || true
      ${formatter.messages.info "Backup at $backup_root"}
      echo "$backup_root"
    }

    # nix eval helper: call an attr on layout-convert.nix
    nix_convert() {
      local attr="$1"
      shift
      "$NIX_BIN" --extra-experimental-features 'nix-command' eval --impure --raw \
        --expr "(import $CONVERT_LIB {}).$attr { $* }"
    }

    convert_to_monolith() {
      local force="''${1:-false}"
      local current
      current=$(detect_layout)
      if [[ "$current" == "monolith" && "$force" != "true" ]]; then
        # Already monolith — still scrub leftover split leaves so the tree cannot confuse tools/humans
        if has_split_configs; then
          backup_tree >/dev/null
          "$FIND_BIN" "$CONFIGS_DIR" -name 'config.nix' -type f -delete
          ${formatter.messages.info "Already monolith — removed leftover split config.nix leaves under $CONFIGS_DIR"}
        else
          ${formatter.messages.info "Already monolith"}
        fi
        exit 0
      fi
      if [[ "$current" == "none" ]]; then
        ${formatter.messages.error "No configuration found to convert"}
        exit 1
      fi

      backup_tree >/dev/null

      # Warn about leaves that cannot be imported (broken path refs etc.)
      local failed
      failed=$("$NIX_BIN" --extra-experimental-features 'nix-command' eval --impure --raw \
        --expr "let l = import $CONVERT_LIB {}; in builtins.concatStringsSep \"\\n\" (l.failedLeaves $CONFIGS_DIR)" \
        2>/dev/null || true)
      if [[ -n "''${failed:-}" ]]; then
        ${formatter.messages.warning "Some leaf configs could not be imported (skipped):"}
        echo "$failed" >&2
      fi

      local tmp_nix
      tmp_nix=$(mktemp --suffix=.nix)
      if ! nix_convert splitToMonolith \
          "configsDir = $CONFIGS_DIR; monolithPath = $( [[ -f $MONOLITH_FILE ]] && echo "$MONOLITH_FILE" || echo null );" \
          > "$tmp_nix"; then
        ${formatter.messages.error "Failed to build monolith from split configs"}
        rm -f "$tmp_nix"
        exit 1
      fi

      # Validate generated Nix before touching live tree
      if ! "$NIX_INSTANTIATE" --parse "$tmp_nix" >/dev/null 2>&1; then
        ${formatter.messages.error "Generated monolith has invalid Nix syntax — aborting (split leaves kept)"}
        rm -f "$tmp_nix"
        exit 1
      fi
      if ! "$NIX_INSTANTIATE" --eval --strict -E "import $tmp_nix" >/dev/null 2>&1; then
        ${formatter.messages.error "Generated monolith failed to evaluate — aborting (split leaves kept)"}
        rm -f "$tmp_nix"
        exit 1
      fi

      mkdir -p "$CONFIGS_DIR"
      cp "$tmp_nix" "$MONOLITH_FILE"
      rm -f "$tmp_nix"

      if has_split_configs; then
        "$FIND_BIN" "$CONFIGS_DIR" -name 'config.nix' -type f -delete
        ${formatter.messages.info "Removed split config.nix leaves"}
      fi
      ${formatter.badges.success "Converted to monolith: $MONOLITH_FILE"}
    }

    convert_to_split() {
      local force="''${1:-false}"
      local current
      current=$(detect_layout)
      if [[ "$current" == "split" && "$force" != "true" ]]; then
        ${formatter.messages.info "Already split"}
        exit 0
      fi
      if [[ ! -f "$MONOLITH_FILE" ]] && ! has_split_configs; then
        ${formatter.messages.error "No configuration found to convert"}
        exit 1
      fi
      if [[ ! -f "$MONOLITH_FILE" ]]; then
        ${formatter.messages.error "Monolith file missing: $MONOLITH_FILE"}
        exit 1
      fi

      backup_tree >/dev/null

      # Stage into temp dir; only swap after full success
      local stage
      stage=$(mktemp -d)
      mkdir -p "$stage"

      local mod_path leaf
      while IFS= read -r mod_path; do
        [[ -z "$mod_path" ]] && continue
        leaf=$(nix_convert leafFromMonolith \
          "monolithPath = $MONOLITH_FILE; modulePath = \"$mod_path\";" 2>/dev/null || true)
        if [[ -z "''${leaf:-}" ]]; then
          continue
        fi
        mkdir -p "$stage/$mod_path"
        printf '%s' "$leaf" > "$stage/$mod_path/config.nix"
        if ! "$NIX_INSTANTIATE" --parse "$stage/$mod_path/config.nix" >/dev/null 2>&1; then
          ${formatter.messages.error "Invalid leaf generated for $mod_path — aborting"}
          rm -rf "$stage"
          exit 1
        fi
      done < "$MODULE_PATHS_FILE"

      local user
      while IFS= read -r user; do
        [[ -z "$user" ]] && continue
        leaf=$(nix_convert userLeafFromMonolith \
          "monolithPath = $MONOLITH_FILE; username = \"$user\";" 2>/dev/null || true)
        [[ -z "''${leaf:-}" ]] && continue
        mkdir -p "$stage/users/$user"
        printf '%s' "$leaf" > "$stage/users/$user/config.nix"
      done < <(nix_convert userNames "monolithPath = $MONOLITH_FILE;" 2>/dev/null || true)

      if [[ ! -f "$stage/core/management/system-manager/config.nix" ]]; then
        mkdir -p "$stage/core/management/system-manager"
        cat > "$stage/core/management/system-manager/config.nix" <<EOF
{
  configVersion = "2.0";
  layout = "split";
}
EOF
      fi

      # Install staged leaves (merge into existing dir tree)
      "$FIND_BIN" "$stage" -name 'config.nix' -type f | while read -r f; do
        rel="''${f#"$stage"/}"
        mkdir -p "$CONFIGS_DIR/$(dirname "$rel")"
        cp "$f" "$CONFIGS_DIR/$rel"
      done
      rm -rf "$stage"
      rm -f "$MONOLITH_FILE"
      ${formatter.badges.success "Converted to split: $CONFIGS_DIR"}
    }

    CMD="''${1:-}"
    shift || true
    case "$CMD" in
      detect)
        detect_layout
        ;;
      convert)
        TO=""
        FORCE=false
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --to) TO="$2"; shift 2 ;;
            --force) FORCE=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *)
              ${formatter.messages.error "Unknown argument"}
              echo "Got: $1" >&2
              usage
              exit 1
              ;;
          esac
        done
        case "$TO" in
          monolith) convert_to_monolith "$FORCE" ;;
          split) convert_to_split "$FORCE" ;;
          *)
            ${formatter.messages.error "--to monolith|split required"}
            usage
            exit 1
            ;;
        esac
        ;;
      -h|--help|"")
        usage
        exit 0
        ;;
      *)
        ${formatter.messages.error "Unknown command"}
        echo "Got: $CMD" >&2
        usage
        exit 1
        ;;
    esac
  '';
in
{
  configLayout = convertScript;
}
