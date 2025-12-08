{ lib, ... }:

{
  description = "Monolithic structure - all config in system-config.nix";
  
  # Required fields (MUSS vorhanden sein)
  requiredFields = [
    "systemType"
    "hostName"
    "system"
    "allowUnfree"
    "users"
    "timeZone"
  ];
  
  # Optional fields (können vorhanden sein)
  optionalFields = [
    "desktop"
    "hardware"
    "features"
    "packageModules"      # v0 hatte packageModules als Attrset (nicht Array!)
    "locales"
    "keyboardLayout"
    "keyboardOptions"
    "overrides"
    "email"
    "domain"
    "buildLogLevel"
    "system.version"       # v0 hatte system.version (optional)
  ];
  
  # Struktur-Merkmale
  hasConfigsDir = false;
  hasConfigVersion = false;  # Kein configVersion Feld
  
  # Typische Erkennungsmerkmale für v0
  detectionPatterns = [
    "packageModules = {"     # v0 hatte packageModules als Attrset
    "system.version"         # v0 hatte system.version
    "hardware.memory"        # v0 hatte hardware.memory (nicht ram!)
  ];
}

