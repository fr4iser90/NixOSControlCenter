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
  # INSTALL_DEBUG levels: 0=DEBUG, 1=INFO (default), 2=WARN, 3=ERROR
  export INSTALL_DEBUG=1
  export INSTALL_VERBOSE=1
''