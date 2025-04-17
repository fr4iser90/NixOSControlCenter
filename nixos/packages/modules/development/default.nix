# Development default
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vscode
    code-cursor
    git
    delta
  ];
}