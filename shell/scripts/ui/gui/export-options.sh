#!/usr/bin/env bash
# Export install options from setup-options.sh (+ descriptions) for the GUI wizard.
# Plain text sections — single source of truth stays in shell prompts.
#
# Usage: export-options.sh
# Stdout sections consumed by install_wizard.py

set -euo pipefail

GUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="$(cd "$GUI_DIR/../prompts" && pwd)"

# shellcheck source=../prompts/setup-options.sh
source "$PROMPTS_DIR/setup-options.sh"
# shellcheck source=../prompts/descriptions/setup-descriptions.sh
source "$PROMPTS_DIR/descriptions/setup-descriptions.sh"

emit_list() {
  local section="$1"
  shift
  printf '[%s]\n' "$section"
  local item
  for item in "$@"; do
    printf '%s\n' "$item"
  done
  printf '\n'
}

emit_assoc() {
  local section="$1"
  local -n ref="$2"
  printf '[%s]\n' "$section"
  local key
  for key in "${!ref[@]}"; do
    printf '%s=%s\n' "$key" "${ref[$key]}"
  done
  printf '\n'
}

emit_list SYSTEM_PRESETS "${SYSTEM_PRESETS[@]}"
emit_list DEVICE_PRESETS "${DEVICE_PRESETS[@]}"
emit_list FEATURE_GROUPS "${FEATURE_GROUPS[@]}"
emit_list INSTALL_TYPE_OPTIONS "${INSTALL_TYPE_OPTIONS[@]}"
emit_list ADVANCED_OPTIONS "${ADVANCED_OPTIONS[@]}"

# Desktop envs from FEATURE_GROUPS "Desktop Environment:..." + None
printf '[DESKTOP_ENVS]\n'
for group in "${FEATURE_GROUPS[@]}"; do
  if [[ "${group%%:*}" == "Desktop Environment" ]]; then
    IFS='|' read -ra envs <<< "${group#*:}"
    for env in "${envs[@]}"; do
      printf '%s\n' "$env"
    done
  fi
done
printf 'none\n'
printf '\n'

emit_assoc FEATURE_CONFLICTS FEATURE_CONFLICTS
emit_assoc FEATURE_DEPENDENCIES FEATURE_DEPENDENCIES
emit_assoc PRESET_DEFAULT_PACKAGES PRESET_DEFAULT_PACKAGES
emit_assoc DESCRIPTIONS SETUP_DESCRIPTIONS

emit_list DESKTOP_BROWSERS "${DESKTOP_BROWSERS[@]}"
printf '[DESKTOP_BROWSER_DEFAULT]\n%s\n\n' "${DESKTOP_BROWSER_DEFAULT:-firefox}"
