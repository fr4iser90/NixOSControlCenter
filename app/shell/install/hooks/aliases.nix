# app/shell/install/hooks/aliases.nix
{ pkgs }:

let
  inherit (pkgs) lib;
  preflight = import ../preflight { inherit pkgs lib; };
in

''
  # System Checks
  alias check-gpu="${preflight.checks.gpu}/bin/check-gpu"
  alias check-system-information="${preflight.checks.system-information}/bin/check-system-info"
  
  # Disk Management (direkt über pkgs)
  alias list-disks="${pkgs.util-linux}/bin/lsblk -f"
  alias show-partitions="${pkgs.util-linux}/bin/fdisk -l"
  
  # Utilities
  alias log="tail -f $INSTALL_LOG"
  alias clear-mounts="umount -R /mnt"
  alias restart-install="clear-mounts && rm -rf $INSTALL_TMP/* && clear"

  # Installation Commands (TODO)
  # alias install-basic="..."
  # alias install-minimal="..."
  
  # Profile Installation (TODO)
  # alias install-desktop="..."
  # alias install-server="..."
  # alias install-dev="..."
  # alias install-gaming="..."
  
  # Configuration (TODO)
  # alias show-config="..."
  # alias edit-config="..."
  # alias backup-config="..."
''