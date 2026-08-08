# Game engines only (art tools → user-creative preset).
{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    godot_4
    surreal-engine
    unityhub
  ];
}
