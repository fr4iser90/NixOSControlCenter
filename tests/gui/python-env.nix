# Minimal Python env for GUI unit tests.
# Mirrors gui-engine + assistant deps needed by page smoke (not deployed).
{ pkgs ? import <nixpkgs> { } }:
pkgs.python3.withPackages (ps: with ps; [
  pyside6
  pyte
  httpx
])
