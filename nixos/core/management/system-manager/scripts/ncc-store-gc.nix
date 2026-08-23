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
    for a in "$@"; do
      case "$a" in
        --json|-j) json_out=true ;;
        -h|--help|help)
          cat <<EOF
ncc system store-status — Nix store size, generations, GC preview

Usage:
  ncc system store-status [--json]

Shows /nix/store size, boot/system generations, and how many store paths
would be removed by nix-collect-garbage (dry preview; no deletes).

Examples:
  ncc system store-status
  ncc system store-status --json
EOF
          exit 0
          ;;
      esac
    done

    store_path="/nix/store"
    store_size=""
    store_bytes=""
    if [[ -d "$store_path" ]]; then
      store_size=$(nix path-info -Sh "$store_path" 2>/dev/null | awk '{print $1}' || true)
      store_bytes=$(nix path-info -S "$store_path" 2>/dev/null | awk '{print $1}' || true)
    fi

    generations=""
    current_gen=""
    if command -v nixos-rebuild >/dev/null 2>&1; then
      generations=$(nixos-rebuild --list-generations 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
      current_gen=$(nixos-rebuild --list-generations 2>/dev/null | awk '/current/ {print $1; exit}')
    elif [[ -d /nix/var/nix/profiles/system-profiles ]]; then
      generations=$(ls -1 /nix/var/nix/profiles/system-profiles 2>/dev/null | wc -l | tr -d ' ')
    fi

    gc_dead=0
    gc_freed=""
    if command -v nix-collect-garbage >/dev/null 2>&1; then
      dead_tmp=$(mktemp)
      if nix-collect-garbage --print-dead 2>/dev/null >"$dead_tmp"; then
        gc_dead=$(grep -c . "$dead_tmp" 2>/dev/null || echo 0)
        if [[ "$gc_dead" -gt 0 ]]; then
          gc_freed=$(nix path-info -Sh $(cat "$dead_tmp") 2>/dev/null | awk '{s+=$1} END {printf "%.1f", s}' || true)
          if [[ -n "$gc_freed" && "$gc_freed" != "0.0" ]]; then
            gc_freed="''${gc_freed}G"
          else
            gc_freed=""
          fi
        fi
      fi
      rm -f "$dead_tmp"
    fi

    if [[ "$json_out" == true ]]; then
      jq -nc \
        --arg storeSize "$store_size" \
        --arg storeBytes "$store_bytes" \
        --arg generations "$generations" \
        --arg currentGeneration "$current_gen" \
        --argjson gcDeadPaths "$gc_dead" \
        --arg gcFreedEstimate "$gc_freed" \
        '{
          storeSize: (if $storeSize == "" then null else $storeSize end),
          storeBytes: (if $storeBytes == "" then null else ($storeBytes | tonumber?) end),
          generations: (if $generations == "" then null else ($generations | tonumber) end),
          currentGeneration: (if $currentGeneration == "" then null else ($currentGeneration | tonumber) end),
          gcDeadPaths: $gcDeadPaths,
          gcFreedEstimate: (if $gcFreedEstimate == "" then null else $gcFreedEstimate end)
        }'
    else
      echo "storeSize=$store_size"
      echo "storeBytes=$store_bytes"
      echo "generations=$generations"
      echo "currentGeneration=$current_gen"
      echo "gcDeadPaths=$gc_dead"
      echo "gcFreedEstimate=$gc_freed"
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
  ncc system gc [--dry-run]     Preview paths to delete (default)
  sudo ncc system gc --run      Delete unreachable store paths
  sudo ncc system gc --run --optimise   GC + nix-store optimise

Options:
  --dry-run, -d   List dead paths / counts only (no root)
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

    if ! command -v nix-collect-garbage >/dev/null 2>&1; then
      ${ui.messages.error "nix-collect-garbage not found"}
      exit 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.text.header "Nix store GC (dry-run)"}
      fi
      dead_tmp=$(mktemp)
      nix-collect-garbage --print-dead 2>/dev/null >"$dead_tmp" || true
      count=$(grep -c . "$dead_tmp" 2>/dev/null || echo 0)
      ${ui.messages.info "Dead store paths: $count"}
      if [[ "$count" -gt 0 ]]; then
        freed=$(nix path-info -Sh $(cat "$dead_tmp") 2>/dev/null | awk '{s+=$1} END {printf "%.1f", s}' || true)
        if [[ -n "$freed" && "$freed" != "0.0" ]]; then
          ${ui.messages.info "Approx reclaimable: $freed G"}
        fi
        head -20 "$dead_tmp"
        if [[ "$count" -gt 20 ]]; then
          echo "… ($count total; use store-status --json for counts)"
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
