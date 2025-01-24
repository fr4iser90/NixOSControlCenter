# development/game.nix
{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    # Game Engines
    godot_4
    surreal-engine
    unityhub

    # 3D Modeling & Animation
    blender
    maya

    # 2D Art & Animation
    krita
    aseprite
    gimp
    inkscape
  ];
}
