# app/shell/install/hooks/env.nix
{ pkgs }:

let
  aliases = import ./aliases.nix { inherit pkgs; };
in
''
  # Project Structure
  export INSTALL_ROOT="$(pwd)"
  export NIXOS_CONFIG_DIR="$INSTALL_ROOT/nixos"
  
  # Scripts Structure
  export INSTALL_SCRIPTS="$INSTALL_ROOT/app/shell/install/scripts"
  export INSTALL_SCRIPTS_LIB="$INSTALL_SCRIPTS/lib"
  export INSTALL_SCRIPTS_CHECKS="$INSTALL_SCRIPTS/checks"
  export INSTALL_SCRIPTS_SETUP="$INSTALL_SCRIPTS/setup"
  
  # System Config Location
  export SYSTEM_CONFIG_DIR="/etc/nixos"
  
  # Temporary and Backup
  export INSTALL_TMP="/tmp/nixos-install"
  export INSTALL_BACKUP="/tmp/nixos-backup"
  export INSTALL_LOG="/tmp/nixos-install.log"
  
  # Create necessary directories
  mkdir -p $INSTALL_TMP
  mkdir -p $INSTALL_BACKUP
  
  # System
  export NIXPKGS_ALLOW_UNFREE=1
  
  # Debug/Logging
  export INSTALL_DEBUG=0
  export INSTALL_VERBOSE=1
  
  # Set permissions and load libraries
  echo "Setting execute permissions for scripts..."
  chmod +x $INSTALL_SCRIPTS/checks/hardware/*.sh
  chmod +x $INSTALL_SCRIPTS/checks/system/*.sh
  chmod +x $INSTALL_SCRIPTS/setup/modes/*.sh
  chmod +x $INSTALL_SCRIPTS/lib/*.sh
  
  # Load common libraries
  source "$INSTALL_SCRIPTS_LIB/colors.sh"
  source "$INSTALL_SCRIPTS_LIB/logging.sh"
  source "$INSTALL_SCRIPTS_LIB/utils.sh"
  
  ${aliases}
  
  echo "Environment initialized! 🚀"
''