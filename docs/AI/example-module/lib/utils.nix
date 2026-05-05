# General utility functions

{ lib, ... }:

{
  # Example utility function
  exampleFunction = x: x + 1;
  
  # Example: Format value
  formatValue = value: 
    if lib.isString value then value
    else if lib.isInt value then toString value
    else "unknown";
}

