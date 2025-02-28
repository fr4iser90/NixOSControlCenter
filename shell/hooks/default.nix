{ pkgs }:

let
  # Environment Hooks
  paths = import ./env-paths.nix { inherit pkgs; };
  system = import ./env-system.nix { inherit pkgs; };
  temp = import ./env-temp.nix { inherit pkgs; };

  # UI Hooks
  welcome = import ./ui-welcome.nix { inherit pkgs; };
  info = import ./ui-info.nix { inherit pkgs; };
  aliases = import ./ui-aliases.nix { inherit pkgs; };
in 
{
  shellHook = paths + system + temp + welcome + info + aliases;
}