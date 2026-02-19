# Nixify Config Generator
# Generiert system-config.nix aus Snapshot-Report

{ snapshotReport, mappingDatabase, getModuleApi, ... }:

let
  # Parse Snapshot-Report
  report = builtins.fromJSON (builtins.readFile snapshotReport);
  mapping = builtins.fromJSON (builtins.readFile mappingDatabase);
  
  # Nutze bestehende Module-APIs
  moduleManager = getModuleApi "module-manager";
  systemManager = getModuleApi "system-manager";
  
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
  
  # Module extrahieren (nur die mit module)
  modules = builtins.filter (p: p != null && p.module != null) mappedPrograms;
  moduleNames = builtins.map (p: p.module) modules;
  
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
  
  # Hostname aus OS generieren
  hostname = if report.os == "linux" then
    "${(builtins.head (builtins.split " " (report.distro.name or "linux")))}-nixified"
  else
    "${report.os}-nixified";
  
in
{
  # System-Identität
  systemType = "desktop";
  hostName = hostname;
  
  # System-Version
  system = {
    stateVersion = "25.11";
    channel = "stable";
    bootloader = "systemd-boot";
  };
  
  # Desktop-Environment
  desktop = {
    enable = true;
    environment = desktopEnv;
  };
  
  # Packages (unique list)
  packages = builtins.attrValues (builtins.listToAttrs (builtins.map (p: { name = p; value = p; }) packageNames));
  
  # Modules (unique list)
  modules = builtins.attrValues (builtins.listToAttrs (builtins.map (m: { name = m; value = m; }) moduleNames));
  
  # System-Einstellungen
  timeZone = report.settings.timezone or "Europe/Berlin";
  locale = report.settings.locale or "en_US.UTF-8";
  
  # Hardware-Info (für Dokumentation)
  hardware = {
    cpu = report.hardware.cpu or "unknown";
    ram = report.hardware.ram or 0;
    gpu = report.hardware.gpu or "unknown";
  };
  
  # Metadata
  metadata = {
    source_os = report.os;
    source_version = report.version or "unknown";
    generated_at = report.timestamp;
    programs_count = builtins.length report.programs;
    packages_count = builtins.length packageNames;
    modules_count = builtins.length moduleNames;
  };
}
