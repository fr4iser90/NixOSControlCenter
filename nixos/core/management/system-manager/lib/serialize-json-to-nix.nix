# Serialize a JSON file to Nix source via lib.generators.toPretty
# Usage:
#   nix eval --impure --raw -f serialize-json-to-nix.nix --argstr jsonFile /tmp/x.json
{ jsonFile }:
let
  # Prefer flake-locked nixpkgs when NIX_PATH is set; works in impure eval
  lib = (import <nixpkgs> { }).lib;
  data = builtins.fromJSON (builtins.readFile jsonFile);
in
  lib.generators.toPretty { multiline = true; } data + "\n"
