{ lib, colors, ... }:

{
  lists = import ./lists.nix { inherit lib colors; };
  tables = import ./tables.nix { inherit lib colors; };
  progress = import ./progress.nix { inherit lib colors; };
  boxes = import ./boxes.nix { inherit lib colors; };
}