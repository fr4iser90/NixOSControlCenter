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
    stability = "experimental";
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