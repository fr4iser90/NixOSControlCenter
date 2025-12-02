{ config, lib, pkgs, ... }:

{
  imports = [
    ./ollama
    ./databases
#    ./training/axolotl-no-gpu.nix
#    ./training/axolotl-rocm.nix
#    ./training/pytorch-rocm.nix
    ./training/pytorch-training-rocm-hugging.nix
#    ./training/dataset-generator
  ];
    
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-client
  ];
}