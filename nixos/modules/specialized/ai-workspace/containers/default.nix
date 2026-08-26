{ config, lib, pkgs, ... }:

{
  imports = [
    ./ollama
    ./databases
    ./training/pytorch-training-rocm-hugging.nix
  ];

  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-client
  ];
}
