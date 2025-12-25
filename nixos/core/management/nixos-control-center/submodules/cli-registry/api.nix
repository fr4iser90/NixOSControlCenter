{ lib }:

{
  # WORKING CLI Registry API - Direct config access
  registerCommands = commands: {
    core.management.nixos-control-center.submodules.cli-registry.commands = commands;
  };

  # Commands are read directly from config by main-script.nix
  getAllCommands = "READ_FROM_CONFIG";

  version = "1.0.0";
}
