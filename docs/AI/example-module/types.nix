{ lib, ... }:

{
  # Example custom type
  # exampleType = lib.mkOptionType {
  #   name = "exampleType";
  #   description = "Example custom type";
  #   check = x: builtins.isString x || builtins.isInt x;
  #   merge = lib.mergeEqualOption;
  # };
}

