{ pkgs }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    flask
    requests
    click
    pytest
    pytest-sugar
    pytest-instafail
    rich
    flake8
    black
    mypy
    pdoc
    psutil
    tkinter
  ]);
in
[ pythonEnv ]