# Install-wizard tests — run Python unit tests for wizard_logic.
{ pkgs }:
pkgs.runCommand "ncc-install-wizard-tests" {
  buildInputs = [ (pkgs.python3.withPackages (ps: with ps; [ pyside6 ])) ];
} ''
  cp ${../ui/gui/wizard_logic.py} ./wizard_logic.py
  cp ${./test_wizard_logic.py} ./test_wizard_logic.py
  python3 -m unittest test_wizard_logic -v
  touch $out
''
