# Example parser: Parses structured data (JSON, YAML, XML, etc.)
# Parsers convert structured text/data into structured objects

{ pkgs, lib, ... }:

{
  parse = input: ''
    # Example: Parse JSON
    # echo "$input" | ${pkgs.jq}/bin/jq '.key'
    
    # Example: Parse YAML
    # echo "$input" | ${pkgs.yq}/bin/yq '.key'
    
    # Return parsed data
    echo "$input"
  '';
}

