#!/usr/bin/env bash
# Dry-run helpers for the install shell.
# Enable with: NCC_DRY_RUN=1  |  install --dry-run  |  install-dry
#
# When active: wizard + validation still run; no writes to /etc/nixos,
# no password files, no deploy copy, no nixos-rebuild.

ncc_dry_run() {
    case "${NCC_DRY_RUN:-0}" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

ncc_dry_enable() {
    export NCC_DRY_RUN=1
}

ncc_dry_banner() {
    if ncc_dry_run; then
        if declare -F log_warn >/dev/null 2>&1; then
            log_warn "════════════════════════════════════════════════════"
            log_warn " DRY-RUN MODE — nothing will be copied or written"
            log_warn " Wizard + validation only; /etc/nixos untouched"
            log_warn "════════════════════════════════════════════════════"
        else
            echo "[DRY-RUN] Nothing will be copied or written" >&2
        fi
    fi
}

# Log a skipped mutation. Usage: ncc_dry_skip "write" "/path" "optional detail"
ncc_dry_skip() {
    local action="$1"
    local target="${2:-}"
    local detail="${3:-}"
    if declare -F log_info >/dev/null 2>&1; then
        log_info "[DRY-RUN] would ${action}${target:+: $target}"
        if [[ -n "$detail" ]]; then
            # indent multi-line preview
            while IFS= read -r line; do
                log_info "           $line"
            done <<< "$detail"
        fi
    else
        echo "[DRY-RUN] would ${action}${target:+: $target}" >&2
        [[ -n "$detail" ]] && echo "$detail" | sed 's/^/           /' >&2
    fi
    return 0
}

export -f ncc_dry_run
export -f ncc_dry_enable
export -f ncc_dry_banner
export -f ncc_dry_skip
