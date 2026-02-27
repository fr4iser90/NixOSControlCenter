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

  # Get commands by domain
  getCommandsByDomain = config: domain:
    let
      allCommands = config.core.management.cli-registry.api.getRegisteredCommands config;
    in
      lib.filter (cmd: cmd.domain or null == domain) allCommands;

  # Get all unique domains
  getDomains = config:
    let
      allCommands = config.core.management.cli-registry.api.getRegisteredCommands config;
      domains = lib.unique (map (cmd: cmd.domain or "unknown") allCommands);
    in
      lib.sort (a: b: a < b) (lib.filter (d: d != "unknown") domains);

  # Get subcommands of a parent command
  getSubcommands = config: parentName:
    let
      allCommands = config.core.management.cli-registry.api.getRegisteredCommands config;
    in
      lib.filter (cmd: cmd.parent or null == parentName) allCommands;

  # Get top-level commands (no parent) for a domain
  getTopLevelCommands = config: domain:
    let
      domainCommands = config.core.management.cli-registry.api.getCommandsByDomain config domain;
    in
      lib.filter (cmd: cmd.parent or null == null) domainCommands;

  # Get public commands (exclude internal)
  getPublicCommands = config:
    let
      allCommands = config.core.management.cli-registry.api.getRegisteredCommands config;
    in
      lib.filter (cmd: !(cmd.internal or false)) allCommands;
}
