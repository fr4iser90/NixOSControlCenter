# Generic flake host-extras: detect + merge into incoming NCC flake (host-local write).
# Does NOT hardcode jetpack — any host-only input/ref is preserved into the written flake.nix.
{ pkgs, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";

  # Shared Python helpers (extract + merge) — single source for check & merge scripts
  pyLib = pkgs.writeText "ncc_flake_extras.py" ''
import re
import sys
from pathlib import Path

SKIP_INPUT_KEYS = {"url", "flake", "type", "follows", "inputs"}

# Host flakes often use short names; NCC uses *-stable/*-unstable inputs and
# binds the short name in outputs. Merging the short input would duplicate /
# shadow — skip when aliases exist; retarget follows instead.
NCC_INPUT_ALIASES = {
    "nixpkgs": {"nixpkgs-stable", "nixpkgs-unstable"},
    "home-manager": {"home-manager-stable", "home-manager-unstable"},
}


def host_only_extras(live_names, in_names) -> list[str]:
    in_set = set(in_names)
    extras = []
    for n in live_names:
        if n in in_set:
            continue
        aliases = NCC_INPUT_ALIASES.get(n)
        if aliases and (in_set & aliases):
            continue
        extras.append(n)
    return sorted(set(extras))


def is_covered_by_ncc_alias(name: str, in_names) -> bool:
    aliases = NCC_INPUT_ALIASES.get(name)
    return bool(aliases and (set(in_names) & aliases))


def strip_line_comments(text: str) -> str:
    lines = []
    for line in text.splitlines():
        if "#" in line:
            line = line[: line.index("#")]
        lines.append(line)
    return "\n".join(lines)


def find_attr_block(text: str, name: str):
    """Return (start_brace, end_brace) indices for `name = { ... }` (outer braces)."""
    m = re.search(rf"\b{re.escape(name)}\s*=\s*\{{", text)
    if not m:
        return None
    i = m.end() - 1
    depth = 0
    for j in range(i, len(text)):
        c = text[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i, j
    return None


def top_level_input_names(body: str) -> list[str]:
    names = []
    for m in re.finditer(
        r"(?m)^[ \t]*([A-Za-z_][A-Za-z0-9_-]*)\s*(?:\.url\s*=|\s*=)",
        body,
    ):
        name = m.group(1)
        if name in SKIP_INPUT_KEYS:
            continue
        if name not in names:
            names.append(name)
    return names


def extract_input_names(path: str) -> list[str]:
    text = strip_line_comments(Path(path).read_text(encoding="utf-8", errors="replace"))
    span = find_attr_block(text, "inputs")
    if not span:
        return []
    i, j = span
    return top_level_input_names(text[i + 1 : j])


def extract_nixos_module_refs(path: str) -> list[str]:
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    refs = []
    for m in re.finditer(
        r"\b([A-Za-z_][A-Za-z0-9_-]*)\.nixosModules(?:\.default)?\b",
        text,
    ):
        n = m.group(1)
        if n not in refs:
            refs.append(n)
    return refs


def extract_input_decls(path: str, names: set[str]) -> str:
    """Pull declaration snippets for given top-level input names from live flake."""
    raw = Path(path).read_text(encoding="utf-8", errors="replace")
    text = strip_line_comments(raw)
    span = find_attr_block(text, "inputs")
    if not span:
        return ""
    i, j = span
    body = text[i + 1 : j]
    # Map name -> slice in body via brace/assign scan
    decls = []
    for name in sorted(names):
        # name.url = "..." ;
        m_url = re.search(
            rf"(?m)^([ \t]*){re.escape(name)}\.url\s*=\s*[^;]+;",
            body,
        )
        # name = { ... };
        m_block = re.search(rf"(?m)^([ \t]*){re.escape(name)}\s*=\s*\{{", body)
        parts = []
        if m_block:
            bi = m_block.end() - 1
            depth = 0
            end = None
            for k in range(bi, len(body)):
                if body[k] == "{":
                    depth += 1
                elif body[k] == "}":
                    depth -= 1
                    if depth == 0:
                        end = k
                        break
            if end is not None:
                # include trailing ;
                end2 = end + 1
                if end2 < len(body) and body[end2] == ";":
                    end2 += 1
                parts.append(body[m_block.start() : end2].rstrip())
        if m_url:
            # Collect following dotted assigns for same name (follows etc.)
            start = m_url.start()
            chunk_lines = []
            rest = body[start:]
            for line in rest.splitlines(True):
                if re.match(rf"^[ \t]*{re.escape(name)}(\.|\s*=)", line) or (
                    chunk_lines and re.match(rf"^[ \t]*{re.escape(name)}\.", line)
                ):
                    chunk_lines.append(line)
                    if line.rstrip().endswith(";") and not line.strip().startswith(name + " ="):
                        # keep gathering dotted attrs
                        pass
                    # stop when next top-level other name appears
                elif chunk_lines:
                    if re.match(r"^[ \t]*[A-Za-z_]", line) and not re.match(
                        rf"^[ \t]*{re.escape(name)}\.", line
                    ):
                        break
                    if line.strip() == "":
                        break
                if chunk_lines and re.match(rf"^[ \t]*{re.escape(name)}\.", line):
                    if line not in chunk_lines:
                        chunk_lines.append(line)
            # Simpler: all lines matching ^\s*name(\.|$)
            simple = []
            for line in body.splitlines():
                if re.match(rf"^[ \t]*{re.escape(name)}(\.|\s*=)", line):
                    simple.append(line.rstrip())
            if simple:
                parts = ["\n".join(simple)]
        if parts:
            decls.append(parts[0])
    return "\n\n".join(decls)


def rewrite_follows(decl: str, incoming_names: set[str]) -> str:
    """Retarget follows for short names NCC covers via *-stable aliases."""

    def repl(m):
        target = m.group(1)
        if target in incoming_names:
            return m.group(0)
        if target == "nixpkgs" and "nixpkgs-stable" in incoming_names:
            return m.group(0).replace('"nixpkgs"', '"nixpkgs-stable"')
        if target == "home-manager" and "home-manager-stable" in incoming_names:
            return m.group(0).replace('"home-manager"', '"home-manager-stable"')
        return m.group(0)

    return re.sub(r'\.follows\s*=\s*"([^"]+)"', repl, decl)


def merge_flake(live: str, incoming: str, out: str) -> list[str]:
    live_names = extract_input_names(live)
    in_names = extract_input_names(incoming)
    extras = host_only_extras(live_names, in_names)
    # module refs that are host-only (e.g. home-manager.nixosModules with *-stable input)
    for ref in extract_nixos_module_refs(live):
        if ref not in set(in_names) and ref not in extras:
            if is_covered_by_ncc_alias(ref, in_names):
                continue
            extras.append(ref)
    # Defense: never try to merge short names NCC already covers via *-stable
    extras = sorted(
        e for e in set(extras) if not is_covered_by_ncc_alias(e, in_names)
    )

    text = Path(incoming).read_text(encoding="utf-8", errors="replace")
    if not extras:
        Path(out).write_text(text, encoding="utf-8")
        return []

    decls = extract_input_decls(live, set(extras))
    decls = rewrite_follows(decls, in_names)
    if not decls.strip():
        # Module-ref-only names (no matching inputs.* decl) — skip rather than abort
        raise SystemExit(
            f"could not extract declarations for extras: {extras} "
            f"(try --drop-flake-extras if these are only nixpkgs/home-manager aliases)"
        )

    span = find_attr_block(strip_line_comments(text), "inputs")
    # operate on original text; find inputs block in original
    span_raw = find_attr_block(text, "inputs")
    if not span_raw:
        raise SystemExit("incoming flake has no inputs = { }")
    i, j = span_raw
    insert = "\n\n    # --- ncc-host-extras (merged by system-update; do not edit by hand) ---\n"
    insert += decls
    if not insert.rstrip().endswith(";"):
        insert += ";"
    insert += "\n"
    # insert before closing brace of inputs
    text = text[:j] + insert + text[j:]

    # Ensure outputs args include extras (before , ... or }: )
    def add_outputs_args(s: str, names: list[str]) -> str:
        m = re.search(r"outputs\s*=\s*\{([^}]*)\}", s, re.S)
        if not m:
            return s
        args = m.group(1)
        have = set(re.findall(r"[A-Za-z_][A-Za-z0-9_-]*", args))
        add = [n for n in names if n not in have]
        if not add:
            return s
        # Prefer insert before `...`
        if "..." in args:
            new_args = args.replace("...", ", ".join(add) + ", ...", 1)
            # fix double commas
            new_args = re.sub(r",\s*,", ",", new_args)
        else:
            new_args = args.rstrip() + "".join(f", {n}" for n in add) + "\n  "
        return s[: m.start(1)] + new_args + s[m.end(1) :]

    text = add_outputs_args(text, extras)

    # Inject nixosModules.default for extras that used it on live
    live_mod_refs = set(extract_nixos_module_refs(live)) & set(extras)
    if live_mod_refs:
        mods = " ++ [ " + " ".join(f"{n}.nixosModules.default" for n in sorted(live_mod_refs)) + " ]"
        # After systemModules in modules list
        if "++ systemModules" in text and mods not in text:
            text = text.replace(
                "] ++ systemModules",
                "] ++ systemModules" + mods,
                1,
            )
        elif "systemModules ++" in text and mods not in text:
            text = text.replace(
                "systemModules ++",
                "systemModules" + mods + " ++",
                1,
            )

    # specialArgs: inherit extras so modules can take them if needed
    if "specialArgs = {" in text:
        inherit_line = "            inherit " + " ".join(sorted(extras)) + ";\n"
        if inherit_line.strip() not in text:
            text = text.replace(
                "specialArgs = {",
                "specialArgs = {\n" + inherit_line,
                1,
            )

    header = (
        "# NOTE: host flake extras merged by ncc system-update "
        f"({', '.join(extras)}). Re-run update to refresh from NCC + live extras.\n"
    )
    if not text.lstrip().startswith("# NOTE: host flake extras"):
        text = header + text

    Path(out).write_text(text, encoding="utf-8")
    return extras
'';

  checkScript = pkgs.writeScriptBin "ncc-check-flake-extras" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    LIVE=""; INCOMING=""; JSON=false
    while [ $# -gt 0 ]; do
      case "$1" in
        --live) LIVE="''${2:-}"; shift ;;
        --incoming) INCOMING="''${2:-}"; shift ;;
        --json) JSON=true ;;
        -h|--help)
          echo "Usage: ncc-check-flake-extras --live FLAKE --incoming FLAKE [--json]"
          echo "Exit 0 = no extras; 2 = host-only extras present"
          exit 0 ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
      esac
      shift || true
    done
    [ -n "$LIVE" ] && [ -n "$INCOMING" ] && [ -f "$LIVE" ] && [ -f "$INCOMING" ] || {
      echo "need --live and --incoming flake files" >&2; exit 1
    }
    ${pkgs.python3}/bin/python3 - "$LIVE" "$INCOMING" "$JSON" <<'PY'
import json, sys
sys.path.insert(0, "${pyLib}")
# load helpers from file path
import importlib.util
spec = importlib.util.spec_from_file_location("ncc_flake_extras", "${pyLib}")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
live, incoming, as_json = sys.argv[1], sys.argv[2], sys.argv[3] == "true"
live_n = mod.extract_input_names(live)
in_n = mod.extract_input_names(incoming)
extras = mod.host_only_extras(live_n, in_n)
for ref in mod.extract_nixos_module_refs(live):
    if ref not in set(in_n) and ref not in extras:
        if mod.is_covered_by_ncc_alias(ref, in_n):
            continue
        extras.append(ref)
extras = sorted(set(extras))
if as_json:
    print(json.dumps({"liveInputs": live_n, "incomingInputs": in_n, "hostOnlyExtras": extras, "safe": len(extras)==0}))
else:
    if extras:
        print("host-only extras: " + ", ".join(extras))
sys.exit(0 if not extras else 2)
PY
  '';

  mergeScript = pkgs.writeScriptBin "ncc-merge-flake-extras" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    LIVE=""; INCOMING=""; OUT=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --live) LIVE="''${2:-}"; shift ;;
        --incoming) INCOMING="''${2:-}"; shift ;;
        --out) OUT="''${2:-}"; shift ;;
        -h|--help)
          echo "Usage: ncc-merge-flake-extras --live HOST.nix --incoming NCC.nix --out MERGED.nix"
          exit 0 ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
      esac
      shift || true
    done
    [ -n "$LIVE" ] && [ -n "$INCOMING" ] && [ -n "$OUT" ] || {
      echo "need --live --incoming --out" >&2; exit 1
    }
    ${pkgs.python3}/bin/python3 - "$LIVE" "$INCOMING" "$OUT" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("ncc_flake_extras", "${pyLib}")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
extras = mod.merge_flake(sys.argv[1], sys.argv[2], sys.argv[3])
if extras:
    print("merged host extras: " + ", ".join(extras))
else:
    print("no host extras — wrote incoming flake unchanged")
PY
  '';

in {
  inherit checkScript mergeScript pyLib;
  nixosModule = {
    environment.systemPackages = [ checkScript mergeScript ];
  };
}
