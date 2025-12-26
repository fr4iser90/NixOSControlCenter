# Haupt-Validator - orchestriert alle Validierungen
{ lib, ... }:

let
  schemaValidators = import ./schema/validators.nix { inherit lib; };
  
  # Zusätzliche Validierungen
  validateMetadata = moduleData:
    let
      meta = moduleData.metadata or {};
    in {
      valid = (meta.name or "") != "" && (meta.version or "") != "";
      errors = if valid then [] else ["Missing required metadata: name, version"];
    };

  validateStructure = modulePath: moduleData:
    let
      expectedFiles = if moduleData.type == "monolithic" 
                      then ["module.nix"]
                      else ["default.nix", "options.nix"];
      missing = builtins.filter (f: !builtins.pathExists "${modulePath}/${f}") expectedFiles;
    in {
      valid = missing == [];
      errors = map (f: "Missing required file: ${f}") missing;
    };

in {
  # Komplette Modul-Validierung
  validateCompleteModule = modulePath:
    let
      moduleData = import modulePath;
      
      schemaResult = schemaValidators.validateModule moduleData;
      metadataResult = validateMetadata moduleData;
      structureResult = validateStructure modulePath moduleData;
      
      allValid = schemaResult.valid && metadataResult.valid && structureResult.valid;
      allErrors = schemaResult.errors ++ metadataResult.errors ++ structureResult.errors;
    in {
      valid = allValid;
      errors = allErrors;
      details = {
        schema = schemaResult;
        metadata = metadataResult;
        structure = structureResult;
      };
    };

  # Schnell-Validierung für Discovery
  quickValidate = modulePath:
    let
      type = schemaValidators.detectModuleType modulePath;
    in {
      valid = type != "invalid";
      type = type;
      path = modulePath;
    };
}