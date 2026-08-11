# Aggregate module ui/gui/ pages into importable ncc_domain_page.<id>
# Discovery: modules call cliRegistry.registerGuiPage "<id>" ./ui/gui
#
# Each domain becomes a *package* (not a single flat .py) so sibling helpers work:
#   from .intent_store import …   /   from .preflight import …
{ lib, pkgs, guiPages }:

let
  sanitize = id: lib.replaceStrings [ "-" ] [ "_" ] id;
  entries = lib.mapAttrsToList (id: g: { inherit id; path = g.path; }) guiPages;
in
pkgs.runCommand "ncc-domain-pages" { } ''
  mkdir -p $out/ncc_domain_page
  touch $out/ncc_domain_page/__init__.py
  ${lib.concatMapStringsSep "\n" (e: ''
    if [ ! -f "${e.path}/page.py" ]; then
      echo "registerGuiPage '${e.id}': missing ${e.path}/page.py" >&2
      exit 1
    fi
    mkdir -p "$out/ncc_domain_page/${sanitize e.id}"
    # Copy all Python helpers next to page.py (intent_store, preflight, …)
    for f in "${e.path}"/*.py; do
      [ -f "$f" ] || continue
      cp -L "$f" "$out/ncc_domain_page/${sanitize e.id}/"
    done
    if [ ! -f "$out/ncc_domain_page/${sanitize e.id}/__init__.py" ]; then
      printf '%s\n' \
        '"""Domain page package — re-exports Page / create_page."""' \
        'from .page import *  # noqa: F401,F403' \
        > "$out/ncc_domain_page/${sanitize e.id}/__init__.py"
    fi
  '') entries}
''
