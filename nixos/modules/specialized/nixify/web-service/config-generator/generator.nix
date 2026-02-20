# Nixify Config Generator
# Generiert NUR configs/*.nix Dateien aus Snapshot-Report
# Das komplette NixOSControlCenter Repository wird von der ISO eingebettet
# KEINE FALLBACKS - Fehler wenn Daten fehlen!

{ snapshotReport, mappingDatabase, ... }:

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
  
  # Desktop-Environment basierend auf OS - KEINE FALLBACKS!
  desktopEnv = if report.os == "linux" then
    let
      desktop = report.settings.desktop or (throw "Missing desktop in snapshot report settings");
      linuxMapping = mapping.desktop_mapping.linux or (throw "Missing linux desktop mapping in database");
      desktopMapping = linuxMapping.${desktop} or linuxMapping.default or (throw "No desktop mapping found for '${desktop}' and no default in mapping database");
    in
      desktopMapping.preferred_de or (throw "Missing preferred_de in desktop mapping for '${desktop}'")
  else
    let
      osMapping = mapping.desktop_mapping.${report.os} or (throw "Missing desktop mapping for OS '${report.os}' in mapping database");
    in
      osMapping.preferred_de or (throw "Missing preferred_de in desktop mapping for OS '${report.os}'");
  
  # Timezone und Locale - KEINE FALLBACKS!
  timeZone = report.settings.timezone or (throw "Missing timezone in snapshot report settings");
  locale = report.settings.locale or (throw "Missing locale in snapshot report settings");
  
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
  # NUR configs/*.nix Dateien - das komplette Repository kommt von der ISO!
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
