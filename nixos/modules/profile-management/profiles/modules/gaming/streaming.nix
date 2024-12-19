{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    obs-studio
    obs-studio-plugins.wlrobs 
    streamlink
  ];
}