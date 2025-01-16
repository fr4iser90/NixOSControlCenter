# validate-vars.nix
{ lib, ... }:

with lib;

let
  types = lib.types;

  validateVar = name: varDef: providedValue:
  let
      value =
      if providedValue != null then
          providedValue
      else if varDef.default != null then
          varDef.default
      else
          "someDefault";
  in
      if varDef.required && value == null then
      throw "Missing required variable: ${name}"
      else
      value;

  validateVars = containerVars: providedVars:
    lib.mapAttrs (name: varDef:
      validateVar name varDef (providedVars.${name} or null)
    ) containerVars;

in {
  options.validateVars = mkOption {
    type = types.anything;  # simplest approach: no advanced function checks
    default = validateVars;
    description = "A function to validate container vars.";
  };

  config = {
    # So now in your final config, `config.validateVars`
    # is the function we defined above
    validateVars = validateVars;
  };
}
