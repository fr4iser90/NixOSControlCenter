# Development default
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vscode
    git
    git-credential-manager
    delta
  ];
  programs.git = {
    enable = true;
    config = {
      credential.helper = "manager";
    };
  };
}