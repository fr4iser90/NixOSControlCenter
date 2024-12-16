# app/shell/dev/hooks/default.nix
{ pkgs }:

let
  envHook = import ./env.nix { inherit pkgs; };
  aliasesHook = import ./aliases.nix { inherit pkgs; };
  infoHook = import ./info.nix { inherit pkgs; };
  welcomeHook = import ./welcome.nix { inherit pkgs; };
in {
  shellHook = envHook + welcomeHook + aliasesHook + infoHook;
}