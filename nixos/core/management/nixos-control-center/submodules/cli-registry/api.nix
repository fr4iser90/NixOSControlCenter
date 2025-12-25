{ lib }:

# CLI Registry API - Elegant command registration system
# Each module registers under a unique key, then we collect all
{
  # Register commands for a specific module
  registerCommandsFor = moduleName: commands: {
    core.management.nixos-control-center.submodules.cli-registry.commandSets.${moduleName} = commands;
  };

  # Get all registered commands (flattened)
  getRegisteredCommands = config:
    let
      commandSets = config.core.management.nixos-control-center.submodules.cli-registry.commandSets or {};
    in
      builtins.concatLists (builtins.attrValues commandSets);

  version = "1.0.0";
}
