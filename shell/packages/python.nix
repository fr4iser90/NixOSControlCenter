# app/shell/install/packages/python.nix
{ pkgs }:

let
  # tkinter powers shell/scripts/ui/gui/install_wizard.py
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pip
    setuptools
    tkinter
  ]);
in
[ pythonEnv ]
