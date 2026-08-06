{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
in
{
  _module.metadata = {
    role = "optional";
    name = "ncc-assistant";
    description = "AI chat + MCP tools for explaining and editing NCC systemConfig";
    category = "specialized";
    subcategory = "ai";
    stability = "beta";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    (import ./commands.nix {
      inherit config lib pkgs systemConfig getModuleConfig getModuleApi;
      moduleName = moduleName;
    })
  ];
}
