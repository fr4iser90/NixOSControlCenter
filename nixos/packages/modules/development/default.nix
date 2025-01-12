# Development default
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Development
    vscode
    code-cursor
    git
    git-credential-manager
    delta
    godot_4
  ];

  programs.git = {
    enable = true;
    config = {
      credential.helper = "manager";
    };
  };
}