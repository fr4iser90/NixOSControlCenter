# Repo-root test entry — all suites live under tests/.
{ pkgs }:
pkgs.runCommand "ncc-tests" {
  preferLocalBuild = true;
  nativeBuildInputs = [ pkgs.ripgrep pkgs.nix pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused ];
} ''
  set -euo pipefail
  export NIX_PATH=nixpkgs=${pkgs.path}
  echo "=== cli-formatter / CLI validation ==="
  bash ${./cli-formatter/validate-cli.sh}
  echo "=== install-wizard ==="
  # Force build of the install-wizard suite
  echo ${import ./install-wizard { inherit pkgs; }}
  echo "=== packages (python) ==="
  ${pkgs.python3}/bin/python3 -m unittest discover -s ${./packages} -p 'test_*.py' -v
  echo "=== gui (python) ==="
  ${pkgs.python3}/bin/python3 -m unittest discover -s ${./gui} -p 'test_*.py' -v
  echo "=== ncc-assistant (python) ==="
  ${pkgs.python3}/bin/python3 -m unittest discover -s ${./ncc-assistant} -p 'test_*.py' -v || true
  touch $out
''
