{ pkgs }:

let
  paths = import ./env-paths.nix { inherit pkgs; };
  system = import ./env-system.nix { inherit pkgs; };
  temp = import ./env-temp.nix { inherit pkgs; };
  aliases = import ./ui-aliases.nix { inherit pkgs; };
in
''
  # Load all environment configurations
  ${paths}
  ${system}
  ${temp}
  
  # Set permissions and load libraries
  echo "Setting execute permissions for scripts..."
  source "$SECURITY_DIR/setup-permissions.sh"
  
  # Load common libraries
  source "$LIB_DIR/colors.sh"
  source "$LIB_DIR/logging.sh"
  source "$LIB_DIR/utils.sh"
  
  ${aliases}
  
  echo "Environment initialized! 🚀"
''