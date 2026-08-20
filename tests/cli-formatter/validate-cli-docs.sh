#!/usr/bin/env bash
# Back-compat entry — full suite lives in validate-cli.sh
exec "$(cd "$(dirname "$0")" && pwd)/validate-cli.sh" "$@"
