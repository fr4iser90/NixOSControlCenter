# Repo-root test entry — all suites live under tests/ (never under nixos/).
{ pkgs }:
pkgs.runCommand "ncc-tests" {
  preferLocalBuild = true;
  nativeBuildInputs = [ pkgs.ripgrep pkgs.nix pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.python3 ];
} ''
  set -euo pipefail
  export NIX_PATH=nixpkgs=${pkgs.path}
  echo "=== hard gates (validate-ncc-nix) ==="
  bash ${./validate-ncc-nix.sh}
  echo "=== cli-formatter / CLI validation ==="
  bash ${./cli-formatter/validate-cli.sh}
  echo "=== install-wizard ==="
  echo ${import ./install-wizard { inherit pkgs; }}
  echo "=== packages (python) ==="
  ${pkgs.python3}/bin/python3 -m unittest discover -s ${./packages} -p 'test_*.py' -v
  echo "=== gui (python) ==="
  bash ${./gui/validate-gui-python.sh}
  echo "=== ncc-assistant (python) ==="
  ${pkgs.python3}/bin/python3 -m unittest discover -s ${./ncc-assistant} -p 'test_*.py' -v
  touch $out
''
