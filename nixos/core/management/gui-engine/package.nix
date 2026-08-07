# Need -m to work: domain_gui as module under ncc_gui
{ pkgs }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [ pyside6 ]);
  src = pkgs.runCommand "ncc-gui-engine-src" { } ''
    mkdir -p $out/ncc_gui/assets
    cp -r ${./python/ncc_gui}/. $out/ncc_gui/
    cp -f ${./assets}/ncc-icon.png $out/ncc_gui/assets/ncc-icon.png
    cp -f ${./assets}/ncc-icon.svg $out/ncc_gui/assets/ncc-icon.svg
  '';
in
{
  inherit src pythonEnv;
  pythonPath = "${src}";
  iconPng = ./assets/ncc-icon.png;
  iconSvg = ./assets/ncc-icon.svg;
}
