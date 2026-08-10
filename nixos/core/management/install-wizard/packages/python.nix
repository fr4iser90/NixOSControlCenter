# Install-shell Python: PySide6 for wizard + gui_ask (NCC design kit)
{ pkgs }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pip
    setuptools
    pyside6
  ]);
in
[ pythonEnv ]
