# Example migration: Migrate from v0 to v1.0
# This is called automatically when version changes

{ lib, ... }:

{
  fromVersion = "0";
  toVersion = "1.0";
  
  # Option renamings (old → new)
  optionRenamings = {
    # "features.example-module.oldOption" = "features.example-module.newOption";
  };
  
  # Option removals
  optionsRemoved = [
    # "features.example-module.deprecatedOption"
  ];
  
  # Option additions (new options with defaults)
  optionsAdded = {
    # "features.example-module.newOption" = {
    #   type = "str";
    #   default = "default";
    #   description = "New option";
    # };
  };
  
  # Migration script (optional)
  migrationScript = ''
    # Custom migration logic if needed
    # echo "Migrating from v0 to v1.0"
  '';
}

