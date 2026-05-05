# Validation utility functions

{ lib, ... }:

{
  # Example: Validate string
  validateString = str: 
    lib.isString str && str != "";
  
  # Example: Validate number range
  validateRange = min: max: value:
    lib.isInt value && value >= min && value <= max;
}

