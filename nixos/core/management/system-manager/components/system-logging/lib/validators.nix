{ lib }:

let
  # Validate collector configuration
  validateCollectorConfig = collectorName: config:
    let
      errors = lib.flatten [
        (if !(lib.isAttrs config) then ["Collector ${collectorName} config must be an attribute set"] else [])
        (if config.enable or false then [
          (if !(config ? priority) then ["Collector ${collectorName} missing priority"] else [])
          (if !(lib.isInt config.priority) then ["Collector ${collectorName} priority must be an integer"] else [])
        ] else [])
      ];
    in errors;

  # Validate detail level
  validateDetailLevel = level:
    let
      validLevels = ["basic" "info" "debug" "trace"];
    in lib.elem level validLevels;

  # Validate collector priority range
  validatePriority = priority:
    lib.isInt priority && priority >= 0 && priority <= 1000;

in {
  inherit validateCollectorConfig validateDetailLevel validatePriority;
}
