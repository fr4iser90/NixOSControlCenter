# Formatting utilities for the reporting module
{ lib, colors }:

with lib;

{
  listItems = color: items: 
    concatMapStrings (item: ''
      echo -e "${color}  - ${item}${colors.reset}"
    '') items;

  header = color: text: ''
    echo -e "\n${color}=== ${text} ===${colors.reset}"
  '';
}