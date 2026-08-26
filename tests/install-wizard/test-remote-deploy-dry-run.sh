#!/usr/bin/env bash
# Dry-run remote Install deploy — stage on Host + SSH/rsync -n to Target.
# Does NOT write Target /etc/nixos. Safe to run against Jetson before GUI install.
#
# Usage:
#   bash tests/install-wizard/test-remote-deploy-dry-run.sh
#   bash tests/install-wizard/test-remote-deploy-dry-run.sh fr4iser@192.168.178.41
#
# Env:
#   NCC_INSTALL_REMOTE_TARGET  default SSH target (e.g. fr4iser@192.168.178.41)
#   NCC_TARGET_SUDO_PASSWORD   Target login password when sudo -n fails (optional)
#   NCC_INSTALL_BLUEPRINT        default: fr4iser-jetson-orin
#   NCC_INSTALL_REPO             Host nixos tree override
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
TARGET="${1:-${NCC_INSTALL_REMOTE_TARGET:-fr4iser@192.168.178.41}}"
export NCC_INSTALL_REMOTE_TARGET="$TARGET"
exec python3 "$DIR/test_remote_deploy_dry_run.py" "$TARGET"
