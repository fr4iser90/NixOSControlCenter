{ config, lib, colors }:

{
  text = import ./text.nix { inherit lib colors; };
  layout = import ./layout.nix { inherit lib colors; };
}