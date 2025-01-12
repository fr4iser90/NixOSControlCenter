{ config, lib, pkgs, ... }:

{
  imports = [
    ./containers
    ./schemas
    ./llm
  ];
}