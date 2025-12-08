{ lib, pkgs, ... }:

let
  distroLib = import ./distros.nix { inherit lib; };
  vmLib = import ./vm.nix { inherit lib pkgs; };
  typeLib = import ./types.nix { inherit lib; };
in {
  # DIREKT EXPORTIEREN, KEIN VM NAMESPACE!
  inherit (vmLib) mkVmScript;
  inherit (typeLib) vmConfig;
  inherit (distroLib) getDistroUrl validateDistro;
  distros = distroLib.distros;
}