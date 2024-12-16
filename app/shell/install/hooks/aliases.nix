# app/shell/install/hooks/aliases.nix
{ pkgs }:

''
  # Installation Commands
  alias install-basic="bash $INSTALL_ROOT/scripts/install-basic.sh"
  alias install-minimal="bash $INSTALL_ROOT/scripts/install-minimal.sh"
  
  # Profile Installation
  alias install-desktop="bash $INSTALL_ROOT/scripts/profiles/install-desktop.sh"
  alias install-server="bash $INSTALL_ROOT/scripts/profiles/install-server.sh"
  alias install-dev="bash $INSTALL_ROOT/scripts/profiles/install-dev.sh"
  alias install-gaming="bash $INSTALL_ROOT/scripts/profiles/install-gaming.sh"
  
  # System Checks
  alias check-hardware="bash $INSTALL_ROOT/scripts/checks/hardware.sh"
  alias check-network="bash $INSTALL_ROOT/scripts/checks/network.sh"
  alias check-disk="bash $INSTALL_ROOT/scripts/checks/disk.sh"
  alias check-efi="bash $INSTALL_ROOT/scripts/checks/efi.sh"
  alias check-all="bash $INSTALL_ROOT/scripts/checks/all.sh"
  
  # Disk Management
  alias list-disks="lsblk -f"
  alias show-partitions="fdisk -l"
  alias mount-all="bash $INSTALL_ROOT/scripts/mount-all.sh"
  
  # Configuration
  alias show-config="cat $INSTALL_ROOT/config/current.nix"
  alias edit-config="$EDITOR $INSTALL_ROOT/config/current.nix"
  alias backup-config="cp $INSTALL_ROOT/config/current.nix $INSTALL_BACKUP/config-\$(date +%F-%H%M).nix"
  
  # Utilities
  alias log="tail -f $INSTALL_LOG"
  alias clear-mounts="umount -R /mnt"
  alias restart-install="clear-mounts && rm -rf $INSTALL_TMP/* && clear"
''