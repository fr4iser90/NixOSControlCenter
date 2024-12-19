# Game Development
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
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