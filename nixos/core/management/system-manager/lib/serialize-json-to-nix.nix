# Serialize a JSON file to Nix source (pure builtins — no <nixpkgs> / NIX_PATH).
# Needed during activation scripts where flake systems often have empty NIX_PATH.
#
# Usage:
#   nix eval --impure --raw --expr '(import ./serialize-json-to-nix.nix { jsonFile = "/tmp/x.json"; })'
{ jsonFile }:
let
  data = builtins.fromJSON (builtins.readFile jsonFile);

  indent = depth:
    builtins.concatStringsSep "" (builtins.genList (_: "  ") depth);

  # Valid unquoted Nix attr names (no hyphen — "system-manager" must be quoted)
  needsQuote = name:
    builtins.match "[a-zA-Z_][a-zA-Z0-9_]*" name == null;

  fmtKey = name:
    if needsQuote name then builtins.toJSON name else name;

  toNix = depth: value:
    if value == null then
      "null"
    else if builtins.isBool value then
      (if value then "true" else "false")
    else if builtins.isInt value then
      toString value
    else if builtins.isFloat value then
      toString value
    else if builtins.isString value then
      builtins.toJSON value
    else if builtins.isList value then
      if value == [ ] then
        "[ ]"
      else
        let
          items = map (item: (indent (depth + 1)) + (toNix (depth + 1) item)) value;
        in
          "[\n"
          + builtins.concatStringsSep "\n" items
          + "\n"
          + (indent depth)
          + "]"
    else if builtins.isAttrs value then
      let
        names = builtins.attrNames value;
      in
        if names == [ ] then
          "{ }"
        else
          let
            lines = map (
              name:
              (indent (depth + 1))
              + (fmtKey name)
              + " = "
              + (toNix (depth + 1) value.${name})
              + ";"
            ) names;
          in
            "{\n"
            + builtins.concatStringsSep "\n" lines
            + "\n"
            + (indent depth)
            + "}"
    else
      throw "serialize-json-to-nix: unsupported value";
in
  (toNix 0 data) + "\n"
