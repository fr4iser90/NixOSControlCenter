{ pkgs }:

let
  pythonPackages = import ./python.nix { inherit pkgs; };
  systemPackages = import ./system.nix { inherit pkgs; };
in {
  buildInputs = pythonPackages ++ systemPackages;
}
