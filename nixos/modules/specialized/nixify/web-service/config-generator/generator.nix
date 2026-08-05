# Nixify Config Generator
# Generiert v1 modular systemConfig/*.nix Dateien aus Snapshot-Report
# Das komplette NixOSControlCenter Repository wird von der ISO eingebettet
# KEINE FALLBACKS - Fehler wenn Daten fehlen!

{ snapshotReport, mappingDatabase ? ../../data/mapping-database.nix, ... }:

let
  # Parse Snapshot-Report (external scan input may still be JSON)
  report = builtins.fromJSON (builtins.readFile snapshotReport);
  # Mapping DB is Nix SSOT
  mapping = if builtins.isPath mappingDatabase || builtins.isString mappingDatabase
    then import mappingDatabase
    else mappingDatabase;
  
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
      linuxMapping = mapping.desktop_mapping.linux or (throw "Missing linux desktop mapping in mapping database");
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
  
  # v1 flat config: core/base/desktop/config.nix
  desktopConfig = ''
{
  enable = true;
  environment = "${desktopEnv}";
}
'';
  
  # v1 flat config: core/base/packages/config.nix
  packagesList = builtins.concatStringsSep "\n    " (builtins.map (p: "\"${p}\"") uniquePackages);
  modulesList = builtins.concatStringsSep "\n    " (builtins.map (m: "\"${m}\"") uniqueModules);
  packagesConfig = ''
{
  packageModules = [
    ${modulesList}
  ];
  systemPackages = [
    ${packagesList}
  ];
  userPackages = { };
}
'';
  
  # v1 flat config: core/base/localization/config.nix
  localizationConfig = ''
{
  timeZone = "${timeZone}";
  locales = [ "${locale}" ];
  keyboardLayout = "us";
  keyboardOptions = "";
}
'';
  
in
{
  # v1 modular paths — nested under systemConfig/ on the target system
  configs = {
    "core/base/desktop/config.nix" = desktopConfig;
    "core/base/packages/config.nix" = packagesConfig;
    "core/base/localization/config.nix" = localizationConfig;
  };
  
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
