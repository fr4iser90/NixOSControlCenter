# app/shell/install/preflight/default.nix
{ pkgs, lib }:

{
  checks = {
    gpu = (import ./checks/gpu.nix { inherit pkgs lib; }).check;
    system-information = (import ./checks/system-information.nix { inherit pkgs lib; }).check;
  };
}