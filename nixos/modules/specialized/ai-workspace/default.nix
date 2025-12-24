{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  # Single Source: Modulname nur einmal definieren
  moduleName = "ai-workspace";
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "optional";
    name = moduleName;
    description = "AI workspace with LLM and training capabilities";
    category = "specialized";
    subcategory = "ai";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

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