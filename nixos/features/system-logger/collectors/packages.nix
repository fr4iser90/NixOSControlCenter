{ config, lib, ui, reportLevels, currentLevel, ... }:

with lib;

let
  # Check if a package is free or non-free
  checkPackage = pkg: 
    let
      meta = if pkg ? meta then pkg.meta else {};
    in
    if isDerivation pkg then {
      exists = true;
      isFree = if meta ? license then !(meta.license.free or false) else true;
    } else {
      exists = false;
      isFree = true;
    };

  # Analyze installed packages
  packageAnalysis = let
    allPackages = lib.unique (flatten (with config; [
      (environment.systemPackages or [])
      (programs.packages or [])
      (services.packages or [])
    ]));
    checkedPackages = map checkPackage allPackages;
  in {
    total = length checkedPackages;
    free = filter (p: p.isFree) checkedPackages;
    unfree = filter (p: !p.isFree) checkedPackages;
  };

  # Standard report shows package statistics
  standardReport = ''
    ${ui.text.header "Package Analysis"}
    ${ui.tables.keyValue "Total Packages" (toString packageAnalysis.total)}
    ${ui.tables.keyValue "Free Packages" (toString (length packageAnalysis.free))}
    ${ui.tables.keyValue "Unfree Packages" (toString (length packageAnalysis.unfree))}
  '';

in {
  # Minimal level shows nothing
  collect = if currentLevel >= reportLevels.standard then standardReport else "";
}