{ pkgs }:

let
  envHook = import ./env.nix;
  aliasesHook = import ./aliases.nix;
  infoHook = import ./info.nix;
in {
  shellHook = ''
    echo "Setting up the NixOsControlCenter development environment..."
    
    ${envHook}
    ${aliasesHook}
    ${infoHook}
  '';
}