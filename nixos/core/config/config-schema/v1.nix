{ lib, ... }:

{
  description = "Modular structure - system-config.nix + configs/*.nix";
  
  requiredFields = [
    "configVersion"         # MUSS vorhanden sein in v1.0
    "systemType"
    "hostName"
    "system"
    "allowUnfree"
    "users"
    "timeZone"
  ];
  
  optionalFields = [];  # Alles andere ist in configs/
  
  hasConfigsDir = true;
  hasConfigVersion = true;
  
  # Erwartete Config-Dateien in configs/ (optional, können fehlen)
  expectedConfigFiles = [
    "desktop-config.nix"
    "hardware-config.nix"
    "features-config.nix"
    "packages-config.nix"
    "localization-config.nix"
    "network-config.nix"
    "hosting-config.nix"
    "overrides-config.nix"
    "logging-config.nix"
  ];
  
  # Struktur-Anforderungen
  structure = {
    # system-config.nix sollte minimal sein (~20-30 Zeilen)
    maxSystemConfigLines = 30;
    
    # system-config.nix sollte KEINE dieser Felder haben
    forbiddenInSystemConfig = [
      "desktop"
      "hardware"
      "features"
      "packageModules"
      "locales"
      "keyboardLayout"
      "keyboardOptions"
      "overrides"
      "email"
      "domain"
      "buildLogLevel"
    ];
  };
}

