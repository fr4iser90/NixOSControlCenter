{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  cfg = getModuleConfig "ai-workspace";
in {
  _module.metadata = {
    role = "optional";
    name = "ai-workspace";
    description = "AI workspace with LLM and training capabilities";
    category = "specialized";
    subcategory = "ai";
    version = "1.0.0";
  };

  imports = if cfg.enable or false then [
    ./options.nix
    ./containers
    ./schemas
    ./llm
  ] else [];

  config = mkMerge [
    {
      modules.specialized.ai-workspace.enable = mkDefault (cfg.enable or false);
    }
    (mkIf cfg.enable {
      # Feature-specific config here
    })
  ];
}