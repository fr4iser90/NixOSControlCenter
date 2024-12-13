{ config, lib, colors, formatting, reportLevels, currentLevel, ... }:

with lib;

let
  # Hilfsfunktionen
  safeLicenseString = license:
    if license == null then "unknown"
    else if isAttrs license then (
      if license ? shortName then license.shortName
      else if license ? fullName then license.fullName
      else if license ? spdxId then license.spdxId
      else "unknown"
    )
    else if isList license then
      concatStringsSep ", " (map safeLicenseString license)
    else if isString license then license
    else "unknown";

  uniquePackages = pkgs:
    lib.unique (map (p: p.name) pkgs);

  fullReport = let
    # Limitiere auf Top 20 Pakete für bessere Übersicht
    limitedPackages = lib.take 20 packageAnalysis.packages;
  in ''
    ${detailedReport}
    echo -e "\nPackage Details (showing first 20 packages):"
    ${concatMapStrings (p: ''
      echo "${p.name}:"
      echo "  Version: ${p.version}"
      echo "  License: ${p.license}"
      echo "  Description: ${p.description}"
      echo ""
    '') limitedPackages}
    
    echo "... and ${toString (length packageAnalysis.packages - 20)} more packages"
  '';

  checkPackage = pkg: 
    let
      meta = if pkg ? meta then pkg.meta else {};
      pkgLicense = if meta ? license then meta.license else null;
    in
    if isDerivation pkg then {
      name = pkg.name or "unknown";
      exists = true;
      isFree = if meta ? license then !(meta.license.free or false) else true;
      description = meta.description or "";
      broken = meta.broken or false;
      version = pkg.version or "unknown";
      license = safeLicenseString pkgLicense;
    } else {
      name = toString pkg;
      exists = false;
      isFree = true;
      description = "";
      broken = false;
      version = "unknown";
      license = "unknown";
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
    packages = checkedPackages;
    free = filter (p: p.isFree) checkedPackages;
    unfree = filter (p: !p.isFree) checkedPackages;
    broken = filter (p: p.broken) checkedPackages;
    invalid = filter (p: !p.exists) checkedPackages;
  };

  # Reports für verschiedene Detail-Level
  minimalReport = ''
    printf '%b' "${colors.cyan}=== Package Analysis ===${colors.reset}\n"
    printf 'Total Packages: %d\n' ${toString packageAnalysis.total}
    ${optionalString (packageAnalysis.broken != []) ''
      printf 'Warning: %d broken packages\n' ${toString (length packageAnalysis.broken)}
    ''}
  '';

  standardReport = ''
    ${minimalReport}
    echo -e "Free Packages: ${toString (length packageAnalysis.free)}"
    echo -e "Unfree Packages: ${toString (length packageAnalysis.unfree)}"
  '';

  detailedReport = ''
    ${standardReport}
    ${optionalString (packageAnalysis.broken != []) ''
      echo -e "\nBroken Packages:"
      ${concatMapStrings (p: "  ${p.name}: ${p.description}\n") packageAnalysis.broken}
    ''}
    ${optionalString (packageAnalysis.invalid != []) ''
      echo -e "\nInvalid Packages:"
      ${concatMapStrings (p: "  ${p.name}\n") packageAnalysis.invalid}
    ''}
  '';

in {
  collect = 
    if currentLevel >= reportLevels.full then fullReport
    else if currentLevel >= reportLevels.detailed then detailedReport
    else if currentLevel >= reportLevels.standard then standardReport
    else minimalReport;
}