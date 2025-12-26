{ lib, colors, ... }:

{
  prompts = import ./prompts.nix { inherit lib colors; };
  spinners = import ./spinners.nix { inherit lib colors; };
  fzf = import ./fzf.nix { inherit lib colors; };
  menus = import ./menus.nix { inherit lib colors; };
  tui = import ./tui/api.nix { inherit lib; };
}