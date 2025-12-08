{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.ai-workspace;
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