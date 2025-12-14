# Command Center Utility Functions
{ lib }:

{
  # Generate case blocks for command execution
  generateExecCase = cmd: ''
    ${cmd.name})
      exec "${cmd.script}" "$@"
      ;;
  '';

  # Generate case blocks for detailed help
  generateLongHelpCase = cmd: ''
    ${cmd.name})
      echo "${cmd.longHelp}"
      ;;
  '';

  # Get unique categories from commands
  getUniqueCategories = commands:
    lib.unique (lib.map (command: command.category) commands);

  # Generate command list string
  generateCommandList = commands:
    lib.concatMapStringsSep "\n" (cmd: "  ${cmd.name} - ${cmd.description}") commands;

  # Get valid commands string
  getValidCommands = commands:
    lib.concatStringsSep " " (map (cmd: cmd.name) commands);
}
