{ pkgs }:

let
  pythonPackages = import ./python.nix { inherit pkgs; };
  systemPackages = import ./system.nix { inherit pkgs; };
  bashPackages = import ./bash-shell.nix { inherit pkgs; };
in {
  buildInputs = pythonPackages ++ systemPackages ++ bashPackages;
}
