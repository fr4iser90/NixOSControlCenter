# app/shell/install/packages/python.nix
{ pkgs }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [

    pip
    setuptools
    
  ]);
in
[ pythonEnv ]