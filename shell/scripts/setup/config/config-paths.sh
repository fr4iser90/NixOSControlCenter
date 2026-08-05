#!/usr/bin/env bash
# Installer copy (runtime SSOT: nixos/.../lib/config-facade.nix)
# systemConfig dual-layout paths (generated from config-facade.nix)
NIXOS_ROOT="${NIXOS_ROOT:-${SYSTEM_CONFIG_DIR:-${SYSTEM_CONFIG_DIR_PREFIX:-/etc/nixos}}}"
CONFIGS_BASE="${CONFIGS_BASE:-${NIXOS_ROOT}/systemConfig}"
MONOLITH_FILE="${MONOLITH_FILE:-${NIXOS_ROOT}/systemConfig.nix}"
NCC_DEFAULT_LAYOUT="${NCC_DEFAULT_LAYOUT:-monolith}"

CONFIG_PATH_DESKTOP="${CONFIGS_BASE}/core/base/desktop/config.nix"
CONFIG_PATH_HARDWARE="${CONFIGS_BASE}/core/base/hardware/config.nix"
CONFIG_PATH_PACKAGES="${CONFIGS_BASE}/core/base/packages/config.nix"
CONFIG_PATH_LOCALIZATION="${CONFIGS_BASE}/core/base/localization/config.nix"
CONFIG_PATH_NETWORK="${CONFIGS_BASE}/core/base/network/config.nix"
CONFIG_PATH_USER="${CONFIGS_BASE}/core/base/user/config.nix"
CONFIG_PATH_AUDIO="${CONFIGS_BASE}/core/base/audio/config.nix"
CONFIG_PATH_MODULE_MANAGER="${CONFIGS_BASE}/core/management/module-manager/config.nix"
CONFIG_PATH_SYSTEM_MANAGER="${CONFIGS_BASE}/core/management/system-manager/config.nix"

export NIXOS_ROOT CONFIGS_BASE MONOLITH_FILE NCC_DEFAULT_LAYOUT \
  CONFIG_PATH_DESKTOP CONFIG_PATH_HARDWARE CONFIG_PATH_PACKAGES \
  CONFIG_PATH_LOCALIZATION CONFIG_PATH_NETWORK CONFIG_PATH_USER \
  CONFIG_PATH_AUDIO CONFIG_PATH_MODULE_MANAGER CONFIG_PATH_SYSTEM_MANAGER
