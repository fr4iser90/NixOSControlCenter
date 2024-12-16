# app/shell/install/hooks/env.nix
{ pkgs }:

''
  # Installation Paths
  export INSTALL_ROOT=$(pwd)
  export MOUNT_POINT="/mnt"
  export EFI_MOUNT="$MOUNT_POINT/boot/efi"
  
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