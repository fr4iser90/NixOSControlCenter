{ lib }:

# CLI Registry API - Elegant command registration system
# Each module registers under a unique key, then we collect all
{
  # Register commands for a specific module
  registerCommandsFor = moduleName: commands: {
    core.management.cli-registry.commandSets.${moduleName} = commands;
  };

  # Get all registered commands (flattened)
  getRegisteredCommands = config:
    let
      commandSets = config.core.management.cli-registry.commandSets or {};
    in
      builtins.concatLists (builtins.attrValues commandSets);
}
