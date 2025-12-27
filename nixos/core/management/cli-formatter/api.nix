# CLI Formatter API - Direkter Import für Build-Time
{ lib }:

let
  colors = import ./colors.nix;

  # Components mit leerer config importieren (genau wie in config.nix)
  core = import ./core {
    inherit lib colors;
    config = {};  # Leere config für API
  };

  components = import ./components {
    inherit lib colors;
    config = {};  # Leere config für API
  };

  interactive = import ./interactive {
    inherit lib colors;
    config = {};  # Leere config für API
  };

  status = import ./status {
    inherit lib colors;
    config = {};  # Leere config für API
  };

in {
  inherit colors;
  inherit (core) text layout;
  inherit (components) lists tables progress boxes;
  inherit (interactive) prompts spinners fzf menus tui;
  inherit (status) messages badges;
}
