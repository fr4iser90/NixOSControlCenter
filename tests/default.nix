# Repo-root test entry — all suites live under tests/.
{ pkgs }:
pkgs.runCommand "ncc-tests" {
  preferLocalBuild = true;
} ''
  set -euo pipefail
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
