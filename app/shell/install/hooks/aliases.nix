{ pkgs }:

''
  # System Checks
  alias check-gpu="$INSTALL_SCRIPTS/checks/hardware/gpu.sh"
  alias check-cpu="$INSTALL_SCRIPTS/checks/hardware/cpu.sh"
  alias check-memory="$INSTALL_SCRIPTS/checks/hardware/memory.sh"
  alias check-storage="$INSTALL_SCRIPTS/checks/hardware/storage.sh"
  alias check-users="$INSTALL_SCRIPTS/checks/system/users.sh"

  # System Configuration
  alias check-bootloader="$INSTALL_SCRIPTS/checks/system/bootloader.sh"
  alias check-locale="$INSTALL_SCRIPTS/checks/system/locale.sh"
  alias check-network="$INSTALL_SCRIPTS/checks/system/network.sh"
  
  # Setup Commands
  alias setup-predefined="$INSTALL_SCRIPTS/setup/modes/predefinedSetup.sh"
  alias setup-personalized="$INSTALL_SCRIPTS/setup/modes/personalizedSetup.sh"
  
  # Utilities
  alias log="tail -f $INSTALL_LOG"
  alias clear-mounts="umount -R /mnt"
  alias restart-install="clear-mounts && rm -rf $INSTALL_TMP/* && clear"
  
  # Helper für die Entwicklung
  alias edit-script="$EDITOR $INSTALL_SCRIPTS/"
  alias run-script="bash $INSTALL_SCRIPTS/"
  
  # Disk Management (direkt über pkgs)
  alias list-disks="${pkgs.util-linux}/bin/lsblk -f"
  alias show-partitions="${pkgs.util-linux}/bin/fdisk -l"
''