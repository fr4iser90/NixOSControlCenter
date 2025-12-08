# Example builder: Builds objects/configs/artifacts
# Builders construct complex objects from simpler inputs

{ pkgs, lib, ... }:

{
  build = config: ''
    # Example: Build configuration object
    # Build complex structure from simple config
    
    # Return built object
    echo "Built: $config"
  '';
}

