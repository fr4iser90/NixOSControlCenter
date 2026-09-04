# ncc system store-status / gc — Nix store health and garbage collection
{ pkgs, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";
in
{
  storeStatusScript = pkgs.writeShellScriptBin "ncc-store-status" ''
    set -euo pipefail
    export PATH="${pkgs.coreutils}/bin:${pkgs.nix}/bin:${pkgs.jq}/bin:$PATH"

    json_out=false
    with_gc=false
    for a in "$@"; do
      case "$a" in
        --json|-j) json_out=true ;;
        --with-gc|--gc) with_gc=true ;;
        --skip-gc) with_gc=false ;;
        -h|--help|help)
          cat <<EOF
ncc system store-status — Nix store size, generations, GC preview

Usage:
  ncc system store-status [--json] [--with-gc]

Fast by default (disk + generations). GC dead-path scan is optional and
can take many minutes on large stores (uses: nix-store --gc --print-dead).

Examples:
  ncc system store-status
  ncc system store-status --json
  ncc system store-status --json --with-gc
EOF
          exit 0
          ;;
      esac
    done

    # Disk usage of the filesystem that backs /nix/store.
    # Do NOT use `nix path-info /nix/store` — with flakes it looks for flake.nix and fails.
    store_path="/nix/store"
    store_size=""
    store_bytes=""
    if [[ -d "$store_path" ]]; then
      store_size=$(df -h "$store_path" 2>/dev/null | awk 'NR==2 {print $3 " used / " $2 " (" $5 ")"}' || true)
      store_bytes=$(df -B1 "$store_path" 2>/dev/null | awk 'NR==2 {print $3}' || true)
    fi

    # System profile generations (works without root). Do not call
    # nixos-rebuild list-generations — missing/broken on many flake hosts.
    generations=""
    current_gen=""
    prof="/nix/var/nix/profiles"
    if [[ -d "$prof" ]]; then
      generations=$(find "$prof" -maxdepth 1 -type l -name 'system-[0-9]*-link' 2>/dev/null | wc -l | tr -d ' ' || true)
      cur_link=$(readlink "$prof/system" 2>/dev/null || true)
      current_gen=$(printf '%s\n' "$cur_link" | sed -n 's/^system-\([0-9]*\)-link$/\1/p' || true)
    fi

    # Empty = skipped or unknown. Real 0 only when --with-gc scan succeeds.
    gc_dead=""
    gc_freed=""
    gc_note=""
    if [[ "$with_gc" == true ]]; then
      if command -v nix-store >/dev/null 2>&1; then
        dead_tmp=$(mktemp)
        # Nix 2.3x+: print-dead lives on nix-store --gc, NOT nix-collect-garbage.
        if nix-store --gc --print-dead >"$dead_tmp" 2>/dev/null; then
          # grep -c exits 1 when count is 0 — never `|| echo 0` (doubles stdout).
          gc_dead=$(grep -c . "$dead_tmp" 2>/dev/null || true)
          gc_dead="''${gc_dead:-0}"
        else
          gc_note="print-dead failed"
        fi
        rm -f "$dead_tmp"
      else
        gc_note="nix-store missing"
      fi
    else
      gc_note="skipped (pass --with-gc; slow on large stores)"
    fi

    if [[ "$json_out" == true ]]; then
      jq -nc \
        --arg storeSize "$store_size" \
        --arg storeBytes "$store_bytes" \
        --arg generations "$generations" \
        --arg currentGeneration "$current_gen" \
        --arg gcDeadPaths "$gc_dead" \
        --arg gcFreedEstimate "$gc_freed" \
        --arg gcNote "$gc_note" \
        '{
          storeSize: (if $storeSize == "" then null else $storeSize end),
          storeBytes: (if $storeBytes == "" then null else ($storeBytes | tonumber?) end),
          generations: (if $generations == "" then null else ($generations | tonumber) end),
          currentGeneration: (if $currentGeneration == "" then null else ($currentGeneration | tonumber) end),
          gcDeadPaths: (if $gcDeadPaths == "" then null else ($gcDeadPaths | tonumber) end),
          gcFreedEstimate: (if $gcFreedEstimate == "" then null else $gcFreedEstimate end),
          gcNote: (if $gcNote == "" then null else $gcNote end)
        }'
    else
      echo "storeSize=$store_size"
      echo "storeBytes=$store_bytes"
      echo "generations=$generations"
      echo "currentGeneration=$current_gen"
      echo "gcDeadPaths=$gc_dead"
      echo "gcFreedEstimate=$gc_freed"
      echo "gcNote=$gc_note"
    fi
  '';

  gcScript = pkgs.writeShellScriptBin "ncc-gc" ''
    set -euo pipefail
    export PATH="${pkgs.coreutils}/bin:${pkgs.nix}/bin:$PATH"

    DRY_RUN=true
    DO_OPTIMISE=false
    for a in "$@"; do
      case "$a" in
        --dry-run|-d) DRY_RUN=true ;;
        --run|-y|--yes) DRY_RUN=false ;;
        --optimise|-o) DO_OPTIMISE=true ;;
        -h|--help|help)
          cat <<EOF
ncc system gc — Nix store garbage collection

Usage:
  ncc system gc [--dry-run]     Preview dead paths (can take minutes)
  sudo ncc system gc --run      Delete unreachable store paths
  sudo ncc system gc --run --optimise   GC + nix-store optimise

Options:
  --dry-run, -d   nix-store --gc --print-dead (no deletes; may be slow)
  --run, -y, --yes  Run nix-collect-garbage -d (needs root)
  --optimise, -o  After GC, run nix-store optimise (with --run)
  --help, -h      Show this help

Examples:
  ncc system gc
  ncc system gc --dry-run
  sudo ncc system gc --run
  sudo ncc system gc --run --optimise
EOF
          exit 0
          ;;
      esac
    done

    if [[ "$DRY_RUN" == true ]]; then
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.text.header "Nix store GC (dry-run)"}
      fi
      if ! command -v nix-store >/dev/null 2>&1; then
        ${ui.messages.error "nix-store not found"}
        exit 1
      fi
      ${ui.messages.loading "Scanning dead paths (large stores: minutes)…"}
      dead_tmp=$(mktemp)
      if ! nix-store --gc --print-dead >"$dead_tmp" 2>/dev/null; then
        rm -f "$dead_tmp"
        ${ui.messages.error "nix-store --gc --print-dead failed"}
        exit 1
      fi
      count=$(grep -c . "$dead_tmp" 2>/dev/null || true)
      count="''${count:-0}"
      ${ui.messages.info "Dead store paths: $count"}
      if [[ "$count" -gt 0 ]]; then
        head -20 "$dead_tmp"
        if [[ "$count" -gt 20 ]]; then
          echo "… ($count total)"
        fi
      fi
      rm -f "$dead_tmp"
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: sudo ncc system gc --run"}
      fi
      exit 0
    fi

    if [ "''${EUID:-$(id -u)}" -ne 0 ]; then
      ${ui.messages.error "Run as root: sudo ncc system gc --run"}
      exit 1
    fi

    if ! command -v nix-collect-garbage >/dev/null 2>&1; then
      ${ui.messages.error "nix-collect-garbage not found"}
      exit 1
    fi

    ${ui.text.header "Nix store GC"}
    ${ui.messages.loading "Running nix-collect-garbage -d…"}
    nix-collect-garbage -d
    ${ui.messages.success "Garbage collection finished"}

    if [[ "$DO_OPTIMISE" == true ]]; then
      if command -v nix-store >/dev/null 2>&1; then
        ${ui.messages.loading "Running nix-store optimise…"}
        nix-store --optimise
        ${ui.messages.success "Store optimised"}
      fi
    fi

    ${ui.messages.info "Next: ncc system store-status"}
  '';
}
