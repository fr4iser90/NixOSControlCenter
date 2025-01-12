{ pkgs }:
''
  # Temp and Backup Directories
  export INSTALL_TMP="$SCRIPT_ROOT/tmp/nixos-install"
  export INSTALL_BACKUP="$SCRIPT_ROOT/tmp/nixos-backup"
  export INSTALL_LOG="$SCRIPT_ROOT/tmp/nixos-install.log"
  
  # Create directories
  mkdir -p $INSTALL_TMP
  mkdir -p $INSTALL_BACKUP
  
  # Debug Settings
  export INSTALL_DEBUG=0
  export INSTALL_VERBOSE=1
''