{ lib, ... }:

{
  description = "Modular structure - system-config.nix + configs/*.nix";
  
  requiredFields = [
    "configVersion"         # MUSS vorhanden sein in v1.0
  ];
  
  optionalFields = [];  # Alles andere ist in configs/
  
  hasConfigsDir = true;
  hasConfigVersion = true;
  
  # Erwartete Config-Dateien in systemConfig/ (nested paths, optional)
  expectedConfigFiles = [
    "core/base/desktop/config.nix"
    "core/base/hardware/config.nix"
    "core/base/packages/config.nix"
    "core/base/localization/config.nix"
    "core/base/network/config.nix"
    "core/base/user/config.nix"
    "core/management/system-manager/config.nix"
  ];
  
  # Struktur-Anforderungen
  structure = {
    # system-config.nix sollte minimal sein (~20-30 Zeilen)
    maxSystemConfigLines = 30;
    
    # system-config.nix sollte KEINE dieser Felder haben
    forbiddenInSystemConfig = [
      "desktop"
      "hardware"
      "modules"
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

