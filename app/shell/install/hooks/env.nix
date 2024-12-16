# app/shell/install/hooks/env.nix
{ pkgs }:

''
  # Project Structure
  export INSTALL_ROOT=$(pwd)
  export NIXOS_CONFIG_DIR=$INSTALL_ROOT/nixos
  
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
''