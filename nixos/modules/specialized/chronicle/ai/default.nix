{ config, lib, pkgs, ... }:

{
  imports = [
    ./llm-integration.nix
    ./anomaly-detection.nix
    ./pattern-recognition.nix
  ];
}
