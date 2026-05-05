# Example formatter: Formats data for display
# Formatters convert structured data to text/JSON/tables

{ pkgs, lib, ui, ... }:

{
  format = data: ''
    # Example: Format as table
    ${ui.tables.keyValue "Key" "Value"}
    ${ui.tables.keyValue "Data" "$data"}
    
    # Example: Format as JSON
    # echo "{\"data\": \"$data\"}"
    
    # Example: Format as text
    # echo "Data: $data"
  '';
}

