{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.features.specialized.ai-workspace or {};
in {
  imports = [
    ./options.nix
    ./containers
    ./schemas
    ./llm
  ];

  config = mkMerge [
    {
      features.ai-workspace.enable = mkDefault (systemConfig.features.ai-workspace or false);
    }
    (mkIf cfg.enable {
      # Feature-specific config here
    })
  ];
}