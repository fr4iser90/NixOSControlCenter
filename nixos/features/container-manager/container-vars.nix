{ lib, pkgs, ... }:

with lib;

let
  # Variable type definitions
  varTypes = {
    string = types.str;
    int = types.int;
    bool = types.bool;
    path = types.path;
    enum = enumType: types.enum enumType;
    secret = types.str // {
      check = x: isString x;
      description = "Hashed secret value";
    };
  };

  # Variable validation framework
  validateVar = varDef: val:
    let
      type = varDef.type or varTypes.string;
      hash = varDef.hash or false;
      value = if hash then hashString "sha256" val else val;
    in
      if isFunction type then type val else type.check val;

  # Variable definition structure
  mkVar = name: def:
    let
      type = def.type or varTypes.string;
      description = def.description or "No description provided";
      default = def.default or null;
      hash = def.hash or false;
      required = def.required or false;
    in
      { inherit name type description default hash required; };

  # Centralized variable registry
  containerVars = {
    # Common variables
    TZ = mkVar "TZ" {
      type = varTypes.string;
      description = "Timezone for container";
      default = "UTC";
    };

    # Example secret variable
    DB_PASSWORD = mkVar "DB_PASSWORD" {
      type = varTypes.secret;
      description = "Database password";
      hash = true;
      required = true;
    };
  };

in {
  options.containerManager.vars = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        name = mkOption { type = types.str; };
        type = mkOption { type = types.anything; };
        description = mkOption { type = types.str; };
        default = mkOption { type = types.nullOr types.anything; };
        hash = mkOption { type = types.bool; default = false; };
        required = mkOption { type = types.bool; default = false; };
      };
    });
    default = containerVars;
    description = "Centralized container environment variable definitions";
  };

  config = {
    containerManager.vars = containerVars;
  };
}
