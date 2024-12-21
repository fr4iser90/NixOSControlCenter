# This file contains the tools for the CLI management system.

{ lib, pkgs, cliConfig }:

with lib;

rec {
  # Nutze die Werte aus cliConfig statt config.cli-management
  prefix = cliConfig.prefix;
  categories = cliConfig.categories;

  mkCommand = { 
    category, 
    name, 
    description ? "", 
    longDescription ? "", 
    examples ? [], 
    script 
  }:
    assert assertMsg (hasAttr category categories) 
      "Category ${category} must be one of: ${toString (attrNames categories)}";
    
    pkgs.writeShellScriptBin (mkCommandName { inherit category name; }) ''
      #!/usr/bin/env bash
      
      # Metadata
      COMMAND_NAME="${prefix}-${category}-${name}"
      DESCRIPTION="${description}"
      CATEGORY="${categories.${category}}"
      
      # Help function
      show_help() {
        echo "NixOS Control Center - ''${CATEGORY}"
        echo "Command: ''${COMMAND_NAME}"
        echo
        echo "''${DESCRIPTION}"
        ${optionalString (longDescription != "") ''
          echo
          echo "Details:"
          echo "${longDescription}"
        ''}
        ${optionalString (examples != []) ''
          echo
          echo "Examples:"
          ${concatMapStrings (ex: ''echo "  ${ex}"'') examples}
        ''}
      }
      
      # Parse arguments
      if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_help
        exit 0
      fi
      
      # Main script
      set -e
      ${script}
    '';

  mkCommandName = { category, name }: "${prefix}-${category}-${name}";
}