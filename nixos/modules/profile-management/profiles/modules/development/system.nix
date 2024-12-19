# System Development default
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Development
    vscode
    code-cursor
    git
    git-credential-manager
    delta
    # Build Tools
    cmake
    ninja
    gcc
    clang
  ];

  programs.git = {
    enable = true;
    config = {
      credential.helper = "manager";
    };
  };
}