# Install-wizard tests — repo-root tests/install-wizard/ only.
{ pkgs }:
let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [ pyside6 ]);
  iw = ../../nixos/core/management/install-wizard;
  shellTests = [
    "validate-no-hardcoded-paths"
    "validate-module-imports"
    "validate-bash-embedding"
    "test-presets-dry-run"
    "test-installer-full"
    "test-installer-remaining"
    "test-docker-mode"
    "test-resolve-pins"
  ];
  built = map (name: {
    inherit name;
    drv = import (./. + "/${name}.nix") { inherit pkgs; };
  }) shellTests;
in
pkgs.runCommand "ncc-install-wizard-tests" {
  buildInputs = [ pythonEnv pkgs.ripgrep pkgs.bash pkgs.coreutils pkgs.nix ];
  preferLocalBuild = true;
} ''
  set -euo pipefail
  export NCC_REPO_ROOT=$PWD/repo
  mkdir -p "$NCC_REPO_ROOT"
  ln -s ${../../nixos} "$NCC_REPO_ROOT/nixos"

  echo "=== Python: wizard_logic ==="
  cp ${iw}/ui/gui/wizard_logic.py ./wizard_logic.py
  cp ${./test_wizard_logic.py} ./test_wizard_logic.py
  python3 -m unittest test_wizard_logic -v

  echo "=== Shell validators + installer tests ==="
  ${pkgs.lib.concatMapStrings (t: ''
    echo ">>> ${t.name}"
    NCC_REPO_ROOT="$NCC_REPO_ROOT" bash ${t.drv}
  '') built}

  echo ">>> validate-systemconfig-writes"
  bash ${../validate-systemconfig-writes.sh}

  touch $out
''
