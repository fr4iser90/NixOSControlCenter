# Aggregate module ui/gui/page.py files into importable ncc_domain_page.<id>
# Discovery: modules call cliRegistry.registerGuiPage "<id>" ./ui/gui
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
    cp "${e.path}/page.py" "$out/ncc_domain_page/${sanitize e.id}.py"
  '') entries}
''
