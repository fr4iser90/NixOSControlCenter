#!/usr/bin/env bash
# Installer copy of config facade (runtime SSOT: nixos/.../lib/config-facade.nix → store)
# Config Facade — dual layout (generated from config-facade.nix)
NIX_BIN="${NIX_BIN:-nix}"
NIX_INSTANTIATE_BIN="${NIX_INSTANTIATE_BIN:-nix-instantiate}"
JQ_BIN="${JQ_BIN:-jq}"
SERIALIZE_NIX="${SERIALIZE_NIX:-}"

_ncc_has_split_configs() {
  [[ -d "$CONFIGS_BASE" ]] || return 1
  find "$CONFIGS_BASE" -name 'config.nix' -type f 2>/dev/null | head -1 | grep -q .
}

ncc_detect_layout() {
  if [[ -n "${NCC_LAYOUT:-}" ]]; then
    echo "$NCC_LAYOUT"
    return 0
  fi
  local has_mono=false has_split=false
  [[ -f "$MONOLITH_FILE" ]] && has_mono=true
  _ncc_has_split_configs && has_split=true
  if $has_mono && ! $has_split; then echo "monolith"; return 0; fi
  if $has_split && ! $has_mono; then echo "split"; return 0; fi
  if $has_mono && $has_split; then
    local layout
    layout=$("$NIX_INSTANTIATE_BIN" --eval --strict -E \
      "let c = import ${MONOLITH_FILE}; in c.core.management.system-manager.layout or c.layout or \"monolith\"" \
      2>/dev/null | tr -d '"') || layout="monolith"
    echo "${layout:-monolith}"
    return 0
  fi
  echo "${NCC_DEFAULT_LAYOUT:-monolith}"
}

ncc_ensure_layout() {
  local want="${1:-}"
  case "$want" in
    monolith|split) export NCC_LAYOUT="$want" ;;
    *) echo "ncc_ensure_layout: expected monolith|split" >&2; return 1 ;;
  esac
}

# True if any supported v2+ config exists (monolith file OR split leaves).
# Legacy v0 system-config.nix is NOT counted here — callers handle that separately.
ncc_config_present() {
  [[ -f "$MONOLITH_FILE" ]] && return 0
  _ncc_has_split_configs && return 0
  return 1
}

# When layout is monolith, remove leftover split config.nix leaves (dirs may remain).
# Prints count of deleted files to stdout when > 0.
ncc_scrub_split_leaves_if_monolith() {
  local layout count
  layout=$(ncc_detect_layout)
  [[ "$layout" == "monolith" ]] || return 0
  [[ -d "$CONFIGS_BASE" ]] || return 0
  count=$(find "$CONFIGS_BASE" -name 'config.nix' -type f 2>/dev/null | wc -l)
  count=${count// /}
  if [[ "${count:-0}" -gt 0 ]]; then
    find "$CONFIGS_BASE" -name 'config.nix' -type f -delete
    echo "$count"
  fi
  return 0
}

ncc_module_config_path() {
  local module_path="$1"
  module_path="${module_path#/}"
  module_path="${module_path%.nix}"
  module_path="${module_path%/config}"
  echo "${CONFIGS_BASE}/${module_path}/config.nix"
}

_ncc_path_to_jq_array() {
  local module_path="$1"
  module_path="${module_path//./\/}"
  "$JQ_BIN" -nc --arg p "$module_path" '$p | split("/") | map(select(length > 0))'
}

_ncc_eval_nix_to_json() {
  local nix_expr="$1"
  local tmp
  tmp=$(mktemp --suffix=.nix)
  printf '%s\n' "$nix_expr" > "$tmp"
  "$NIX_INSTANTIATE_BIN" --eval --strict --json -E "import $tmp" 2>/dev/null
  local rc=$?
  rm -f "$tmp"
  return $rc
}

_ncc_json_to_nix() {
  local json_file="$1"
  if [[ -z "$SERIALIZE_NIX" || ! -f "$SERIALIZE_NIX" ]]; then
    echo "serialize-json-to-nix.nix not found" >&2
    return 1
  fi
  "$NIX_BIN" --extra-experimental-features 'nix-command' eval --impure --raw \
    --expr "(import $SERIALIZE_NIX { jsonFile = \"$json_file\"; })"
}

_ncc_write_monolith_json() {
  local json_file="$1"
  local nix_out
  nix_out=$(_ncc_json_to_nix "$json_file") || return 1
  mkdir -p "$(dirname "$MONOLITH_FILE")"
  mkdir -p "$CONFIGS_BASE"
  printf '%s\n' "$nix_out" > "$MONOLITH_FILE"
}

ncc_write_module_config() {
  local module_path="$1"
  local content="$2"
  local layout
  layout=$(ncc_detect_layout)
  module_path="${module_path#/}"
  module_path="${module_path%.nix}"
  module_path="${module_path%/config}"

  if declare -F ncc_dry_run >/dev/null 2>&1 && ncc_dry_run; then
    local target
    if [[ "$layout" == "split" ]]; then
      target=$(ncc_module_config_path "$module_path")
    else
      target="${MONOLITH_FILE:-/etc/nixos/systemConfig.nix} (path: $module_path)"
    fi
    # Validate Nix fragment still parses in dry-run
    if ! _ncc_eval_nix_to_json "$content" >/dev/null; then
      echo "[DRY-RUN] INVALID Nix content for $module_path" >&2
      return 1
    fi
    local preview
    preview=$(printf '%s\n' "$content" | head -n 40)
    ncc_dry_skip "write module config" "$target" "$preview"
    return 0
  fi

  case "$layout" in
    split)
      local config_file
      config_file=$(ncc_module_config_path "$module_path")
      mkdir -p "$(dirname "$config_file")"
      printf '%s\n' "$content" > "$config_file"
      ;;
    monolith)
      local leaf_json current_json path_json merged tmp_json
      leaf_json=$(_ncc_eval_nix_to_json "$content") || {
        echo "Failed to evaluate module content as Nix" >&2
        return 1
      }
      path_json=$(_ncc_path_to_jq_array "$module_path")
      if [[ -f "$MONOLITH_FILE" ]]; then
        current_json=$("$NIX_INSTANTIATE_BIN" --eval --strict --json -E "import $MONOLITH_FILE" 2>/dev/null) || current_json="{}"
      else
        current_json='{"core":{"management":{"system-manager":{"configVersion":"2.0","layout":"monolith"}}}}'
      fi
      merged=$(echo "$current_json" | "$JQ_BIN" \
        --argjson leaf "$leaf_json" \
        --argjson path "$path_json" '
          . as $root
          | ($root | setpath($path; $leaf))
          | .core.management."system-manager".configVersion = (.core.management."system-manager".configVersion // "2.0")
          | .core.management."system-manager".layout = "monolith"
        ')
      tmp_json=$(mktemp --suffix=.json)
      printf '%s\n' "$merged" > "$tmp_json"
      _ncc_write_monolith_json "$tmp_json"
      local rc=$?
      rm -f "$tmp_json"
      return $rc
      ;;
    *)
      echo "Unknown layout: $layout" >&2
      return 1
      ;;
  esac
}

ncc_read_module_config() {
  local module_path="$1"
  local layout
  layout=$(ncc_detect_layout)
  module_path="${module_path#/}"
  case "$layout" in
    split)
      local f
      f=$(ncc_module_config_path "$module_path")
      if [[ -f "$f" ]]; then cat "$f"; else echo "{}"; fi
      ;;
    monolith)
      if [[ ! -f "$MONOLITH_FILE" ]]; then echo "{}"; return 0; fi
      local path_json json leaf tmp_json
      path_json=$(_ncc_path_to_jq_array "$module_path")
      json=$("$NIX_INSTANTIATE_BIN" --eval --strict --json -E "import $MONOLITH_FILE" 2>/dev/null) || json="{}"
      leaf=$(echo "$json" | "$JQ_BIN" -c --argjson path "$path_json" 'getpath($path) // {}')
      tmp_json=$(mktemp --suffix=.json)
      printf '%s\n' "$leaf" > "$tmp_json"
      _ncc_json_to_nix "$tmp_json"
      rm -f "$tmp_json"
      ;;
  esac
}

ncc_set_module_enable() {
  local module_path="$1"
  local enable_value="$2"
  local layout
  layout=$(ncc_detect_layout)
  case "$layout" in
    split)
      local config_file
      config_file=$(ncc_module_config_path "$module_path")
      mkdir -p "$(dirname "$config_file")"
      if [[ ! -f "$config_file" ]]; then
        printf '{\n  enable = %s;\n}\n' "$enable_value" > "$config_file"
        return 0
      fi
      if grep -qE 'enable\s*=' "$config_file"; then
        sed -i "s/enable = true;/enable = ${enable_value};/g; s/enable = false;/enable = ${enable_value};/g" "$config_file"
      else
        sed -i "0,/{/s/{/{\n  enable = ${enable_value};/" "$config_file"
      fi
      ;;
    monolith)
      local current
      current=$(ncc_read_module_config "$module_path")
      if echo "$current" | grep -qE 'enable\s*='; then
        current=$(echo "$current" | sed "s/enable = true;/enable = ${enable_value};/g; s/enable = false;/enable = ${enable_value};/g")
      else
        current=$(echo "$current" | sed "0,/{/s/{/{\n  enable = ${enable_value};/")
      fi
      ncc_write_module_config "$module_path" "$current"
      ;;
  esac
}

write_module_config() {
  ncc_write_module_config "$@"
}

# Resolve serialize helper for installer / live tree
if [[ -z "$SERIALIZE_NIX" ]]; then
  for candidate in \
    "${NIXOS_CONFIG_DIR:-}/core/management/system-manager/lib/serialize-json-to-nix.nix" \
    "${NIXOS_ROOT:-/etc/nixos}/core/management/system-manager/lib/serialize-json-to-nix.nix" \
    "/etc/nixos/core/management/system-manager/lib/serialize-json-to-nix.nix"; do
    if [[ -f "$candidate" ]]; then SERIALIZE_NIX="$candidate"; break; fi
  done
fi
