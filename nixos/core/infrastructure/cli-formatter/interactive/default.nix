{ lib, colors, ... }:

{
  prompts = import ./prompts.nix { inherit lib colors; };
  spinners = import ./spinners.nix { inherit lib colors; };
}