# Schema-basierte Validierung
{ lib, ... }:

let
  # Lade JSON Schema
  loadJsonSchema = name: builtins.fromJSON (builtins.readFile "${name}.json");
  
  # Validiere gegen JSON Schema
  validateWithSchema = schema: data:
    let
      result = lib.runJsonSchema schema data;
    in {
      valid = result.valid;
      errors = if result.valid then [] else result.errors;
    };

  # Spezifische Validatoren
  validateModular = validateWithSchema (loadJsonSchema "modular");
  validateMonolithic = validateWithSchema (loadJsonSchema "monolithic");
  validateSubmodules = validateWithSchema (loadJsonSchema "submodule");

in {
  # Öffentliche API
  validateModule = moduleData:
    let
      type = moduleData.type or "modular";
    in
      if type == "modular" then validateModular moduleData
      else if type == "monolithic" then validateMonolithic moduleData
      else { valid = false; errors = ["Unknown module type: ${type}"]; };

  validateSubmoduleStructure = hierarchy: validateSubmodules { hierarchy = hierarchy; depth = 5; };
  
  # Utility
  detectModuleType = modulePath:
    if builtins.pathExists "${modulePath}/module.nix" then "monolithic"
    else if builtins.pathExists "${modulePath}/options.nix" then "modular"
    else "invalid";
}