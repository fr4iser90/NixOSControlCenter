# Need -m to work: domain_gui as module under ncc_gui
# Ensure package.nix copies pages/ and domain_gui.py
{ pkgs }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [ pyside6 ]);
  src = pkgs.runCommand "ncc-gui-engine-src" { } ''
    mkdir -p $out
    cp -r ${./python/ncc_gui} $out/ncc_gui
  '';
in
{
  inherit src pythonEnv;
  pythonPath = "${src}";
}
