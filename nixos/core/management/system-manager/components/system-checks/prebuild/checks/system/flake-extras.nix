# Generic flake extras detection — compare live host flake vs incoming NCC flake.
# Abort-friendly for system-update: host-only inputs must not be silently overwritten.
{ pkgs, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";

  checkScript = pkgs.writeScriptBin "ncc-check-flake-extras" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    LIVE=""
    INCOMING=""
    JSON=false
    VERBOSE="''${NCC_FLAKE_EXTRAS_VERBOSE:-0}"

    usage() {
      cat <<EOF
Usage: ncc-check-flake-extras --live FLAKE.nix --incoming FLAKE.nix [--json]

Compare direct flake inputs (and obvious input references) on the live host
flake against the incoming NCC flake. Host-only extras would be lost if
flake.nix is overwritten.

Exit codes:
  0  no host-only extras (safe to replace flake.nix)
  2  host-only extras detected (refuse overwrite)
  1  usage / parse error
EOF
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --live) LIVE="''${2:-}"; shift ;;
        --incoming) INCOMING="''${2:-}"; shift ;;
        --json) JSON=true ;;
        --verbose|-v) VERBOSE=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
          echo "Unknown arg: $1" >&2
          usage >&2
          exit 1
          ;;
      esac
      shift || true
    done

    if [ -z "$LIVE" ] || [ -z "$INCOMING" ]; then
      usage >&2
      exit 1
    fi
    if [ ! -f "$LIVE" ] || [ ! -f "$INCOMING" ]; then
      echo "flake file missing (live=$LIVE incoming=$INCOMING)" >&2
      exit 1
    fi

    extract_inputs() {
      ${pkgs.python3}/bin/python3 - "$1" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
lines = []
for line in text.splitlines():
    if "#" in line:
        line = line[: line.index("#")]
    lines.append(line)
text = "\n".join(lines)
m = re.search(r"\binputs\s*=\s*\{", text)
if not m:
    sys.exit(0)
i = m.end() - 1
depth = 0
end = None
for j in range(i, len(text)):
    c = text[j]
    if c == "{":
        depth += 1
    elif c == "}":
        depth -= 1
        if depth == 0:
            end = j
            break
if end is None:
    sys.exit(0)
body = text[i + 1 : end]
names = set()
for m in re.finditer(
    r"(?m)^[ \t]*([A-Za-z_][A-Za-z0-9_-]*)\s*(?:\.url\s*=|\s*=)",
    body,
):
    name = m.group(1)
    if name in ("url", "flake", "type", "follows", "inputs"):
        continue
    names.add(name)
for n in sorted(names):
    print(n)
PY
    }

    mapfile -t LIVE_INPUTS < <(extract_inputs "$LIVE" | sort -u)
    mapfile -t IN_INPUTS < <(extract_inputs "$INCOMING" | sort -u)

    declare -A IN_SET=()
    for n in "''${IN_INPUTS[@]}"; do
      [ -n "$n" ] || continue
      IN_SET["$n"]=1
    done

    ALL_EXTRAS=()
    for n in "''${LIVE_INPUTS[@]}"; do
      [ -n "$n" ] || continue
      if [ -z "''${IN_SET[$n]:-}" ]; then
        ALL_EXTRAS+=("$n")
      fi
    done

    # Also catch foo.nixosModules / foo.overlays refs whose input name is host-only
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      case "$ref" in
        lib|pkgs|config|options|modulesPath|nixpkgs|self) continue ;;
      esac
      if [ -z "''${IN_SET[$ref]:-}" ]; then
        if ! printf '%s\n' "''${ALL_EXTRAS[@]}" | grep -qxF "$ref"; then
          ALL_EXTRAS+=("$ref")
        fi
      fi
    done < <(${pkgs.python3}/bin/python3 - "$LIVE" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
refs = set()
for m in re.finditer(
    r"\b([A-Za-z_][A-Za-z0-9_-]*)\.(nixosModules|overlays)\b",
    text,
):
    refs.add(m.group(1))
for n in sorted(refs):
    print(n)
PY
)

    if [ "$JSON" = true ]; then
      ${pkgs.jq}/bin/jq -n \
        --argjson live "$(printf '%s\n' "''${LIVE_INPUTS[@]}" | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s -c 'map(select(length>0))')" \
        --argjson incoming "$(printf '%s\n' "''${IN_INPUTS[@]}" | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s -c 'map(select(length>0))')" \
        --argjson extras "$(printf '%s\n' "''${ALL_EXTRAS[@]}" | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s -c 'map(select(length>0))')" \
        '{liveInputs:$live, incomingInputs:$incoming, hostOnlyExtras:$extras, safe:(($extras|length)==0)}'
    fi

    if [ "''${#ALL_EXTRAS[@]}" -eq 0 ]; then
      if [ "$VERBOSE" = 1 ] && [ "$JSON" != true ]; then
        ${ui.messages.success "Flake inputs: no host-only extras vs incoming"}
      fi
      exit 0
    fi

    if [ "$JSON" != true ]; then
      ${ui.messages.error "Host flake has inputs/refs missing from incoming NCC flake"}
      echo "  These would be LOST if flake.nix is overwritten:"
      for n in "''${ALL_EXTRAS[@]}"; do
        echo "    - $n"
      done
      ${ui.messages.info "system-update refuses to replace flake.nix (preserve host extras)."}
      ${ui.messages.info "Fix: keep extras on the host, merge them into NCC later, or pass --allow-flake-extras (destructive)."}
    fi
    exit 2
  '';

in {
  inherit checkScript;
  nixosModule = {
    environment.systemPackages = [ checkScript ];
  };
}
