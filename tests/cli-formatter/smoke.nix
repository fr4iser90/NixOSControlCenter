# Smoke: formatter API shape + install-wizard colors.sh + postbuild build.
# Used by tests/cli-formatter/validate-cli.sh
{ pkgs ? import <nixpkgs> { } }:

let
  inherit (pkgs) lib;
  root = ../..;
  colors = import (root + "/nixos/core/management/cli-formatter/colors.nix");
  core = import (root + "/nixos/core/management/cli-formatter/core") {
    inherit lib colors;
    config = { };
  };
  components = import (root + "/nixos/core/management/cli-formatter/components") {
    inherit lib colors;
    config = { };
  };
  interactive = import (root + "/nixos/core/management/cli-formatter/interactive") {
    inherit lib colors;
    config = { };
  };
  status = import (root + "/nixos/core/management/cli-formatter/status") {
    inherit lib colors;
    config = { };
  };
  ui = {
    inherit colors;
    inherit (core) text layout;
    inherit (components) lists tables progress boxes;
    inherit (interactive) prompts spinners fzf menus tui;
    inherit (status) messages badges;
  };
  getModuleApi = name: assert name == "cli-formatter"; ui;
  need = [ "messages" "badges" "text" "tables" "colors" ];
  missing = builtins.filter (n: !(builtins.hasAttr n ui)) need;
  colorsSh = import (root + "/nixos/core/management/install-wizard/scripts/lib/colors.nix") {
    inherit pkgs getModuleApi;
  };
  postbuild = import (root + "/nixos/core/management/system-manager/components/system-checks/scripts/postbuild-checks.nix") {
    inherit pkgs lib getModuleApi;
    config = { };
    systemConfig = { };
    getModuleConfig = _: { };
  };
in
assert missing == [ ];
pkgs.runCommand "ncc-cli-formatter-smoke" { } ''
  set -euo pipefail
  grep -q COLORS_IMPORTED ${colorsSh}
  grep -q "cli-formatter" ${colorsSh}
  test -x ${postbuild}/bin/nixos-postbuild
  echo ok > $out
''
