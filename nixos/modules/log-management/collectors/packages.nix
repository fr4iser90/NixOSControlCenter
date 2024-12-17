{ config, lib, colors, formatting, reportLevels, currentLevel, ... }:

with lib;

let
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

  # Paketanalyse
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

  # Einheitlicher Report für alle Level
  report = ''
    printf '%b' "${colors.cyan}=== Package Analysis ===${colors.reset}\n"
    printf 'Total Packages: %d\n' ${toString packageAnalysis.total}
    echo -e "Free Packages: ${toString (length packageAnalysis.free)}"
    echo -e "Unfree Packages: ${toString (length packageAnalysis.unfree)}"
  '';

in {
  collect = report;
}