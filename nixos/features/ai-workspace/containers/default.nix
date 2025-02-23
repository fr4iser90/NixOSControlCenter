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

  # Docker-Konfiguration (ohne config-Wrapper)
  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
      package = pkgs.docker;
    };
  };
    
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-client
  ];
}