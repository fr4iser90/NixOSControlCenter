# Search & Session Comparison Module
# Aggregates search/tags and comparison functionality
{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./search.nix
    ./comparison.nix
  ];
}
