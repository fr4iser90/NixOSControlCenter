{ lib, ... }:

{
  # Import all library modules
  utils = import ./utils.nix { inherit lib; };
  validators = import ./validators.nix { inherit lib; };
  types = import ./types.nix { inherit lib; };
}
