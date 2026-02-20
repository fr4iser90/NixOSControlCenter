# Nixify Config Generator
# Generiert configs/*.nix Dateien aus Snapshot-Report

{ snapshotReport, mappingDatabase, getModuleApi, ... }:

let
  # Parse Snapshot-Report
  report = builtins.fromJSON (builtins.readFile snapshotReport);
  mapping = builtins.fromJSON (builtins.readFile mappingDatabase);
  
  # Helper: Find program in mapping (with aliases)
  findProgramMapping = programName: 
    let
      # Direct match
      direct = mapping.programs.${programName} or null;
      
      # Alias match
      aliasMatch = builtins.head (builtins.filter (p: 
        builtins.elem programName (p.aliases or [])
      ) (builtins.attrValues mapping.programs)) or []);
      
      aliasResult = if aliasMatch != null then mapping.programs.${aliasMatch.name} else null;
    in
      if direct != null then direct
      else if aliasResult != null then aliasResult
      else null;
  
  # Programme zu Packages/Modulen mappen
  mappedPrograms = builtins.map (program:
    findProgramMapping program.name
  ) report.programs;
  
  # Packages extrahieren (nur die mit nixos_package)
  packages = builtins.filter (p: p != null && p.nixos_package != null) mappedPrograms;
  packageNames = builtins.map (p: p.nixos_package) packages;
  
  # Unique package names
  uniquePackages = builtins.attrValues (builtins.listToAttrs (builtins.map (p: { name = p; value = p; }) packageNames));
  
  # Module extrahieren (nur die mit module)
  modules = builtins.filter (p: p != null && p.module != null) mappedPrograms;
  moduleNames = builtins.map (p: p.module) modules;
  uniqueModules = builtins.attrValues (builtins.listToAttrs (builtins.map (m: { name = m; value = m; }) moduleNames));
  
  # Desktop-Environment basierend auf OS
  desktopEnv = if report.os == "linux" then
    let
      desktop = report.settings.desktop or "unknown";
      linuxMapping = mapping.desktop_mapping.linux or {};
      desktopMapping = linuxMapping.${desktop} or linuxMapping.default or { preferred_de = "plasma"; };
    in
      desktopMapping.preferred_de or "plasma"
  else
    (mapping.desktop_mapping.${report.os} or { preferred_de = "plasma" }).preferred_de;
  
  # Timezone und Locale
  timeZone = report.settings.timezone or "Europe/Berlin";
  locale = report.settings.locale or "en_US.UTF-8";
  
  # Generate desktop-config.nix
  desktopConfig = ''
{
  # Desktop-Environment
  desktop = {
    enable = true;
    environment = "${desktopEnv}";
  };
}
'';
  
  # Generate packages-config.nix
  packagesList = builtins.concatStringsSep "\n    " (builtins.map (p: "\"${p}\"") uniquePackages);
  packagesConfig = ''
{
  # Packages from snapshot
  packages = {
    systemPackages = [
    ${packagesList}
    ];
  };
}
'';
  
  # Generate localization-config.nix
  localizationConfig = ''
{
  # System Settings
  localization = {
    timeZone = "${timeZone}";
    locale = "${locale}";
  };
}
'';
  
  # Generate module-manager-config.nix (if modules found)
  modulesList = if uniqueModules != [] then
    builtins.concatStringsSep "\n      " (builtins.map (m: "${m}.enable = true;") uniqueModules)
  else "";
  
  moduleManagerConfig = if uniqueModules != [] then ''
{
  # Modules from snapshot
  modules = {
${modulesList}
  };
}
'' else "";
  
in
{
  # Config files as strings (ready to write to configs/ directory)
  configs = {
    "desktop-config.nix" = desktopConfig;
    "packages-config.nix" = packagesConfig;
    "localization-config.nix" = localizationConfig;
  } // (if moduleManagerConfig != "" then {
    "module-manager-config.nix" = moduleManagerConfig;
  } else {});
  
  # Metadata for reference
  metadata = {
    source_os = report.os;
    source_version = report.version or "unknown";
    generated_at = report.timestamp;
    programs_count = builtins.length report.programs;
    packages_count = builtins.length uniquePackages;
    modules_count = builtins.length uniqueModules;
    desktop = desktopEnv;
  };
}
