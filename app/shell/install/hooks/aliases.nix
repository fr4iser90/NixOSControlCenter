{ pkgs }:

''
  # Hauptinstallation
  alias install="$INSTALL_SCRIPTS/init.sh"
  
  # Quick-Install Befehle
  install-quick-gaming() {
    local modules=""
    for mod in "$@"; do
      case "$mod" in
        +streaming) modules="$modules --streaming" ;;
        +emulation) modules="$modules --emulation" ;;
      esac
    done
    $INSTALL_SCRIPTS/setup/modes/gaming-setup.sh $modules
  }

  install-quick-server() {
    local modules=""
    for mod in "$@"; do
      case "$mod" in
        +docker) modules="$modules --docker" ;;
        +web) modules="$modules --web" ;;
      esac
    done
    $INSTALL_SCRIPTS/setup/modes/server-setup.sh $modules
  }

  # Alternative Install-Modi
  alias install-workstation="$INSTALL_SCRIPTS/setup/modes/workstation-setup.sh"
  alias install-homelab="$INSTALL_SCRIPTS/setup/modes/homelab-setup.sh"
  
  # Setup-Varianten
  alias setup-predefined="$INSTALL_SCRIPTS/setup/modes/predefinedSetup.sh"
  alias setup-personalized="$INSTALL_SCRIPTS/setup/modes/personalizedSetup.sh"

  # System Checks
  alias check-gpu="$INSTALL_SCRIPTS/checks/hardware/gpu.sh"
  alias check-cpu="$INSTALL_SCRIPTS/checks/hardware/cpu.sh"
  alias check-memory="$INSTALL_SCRIPTS/checks/hardware/memory.sh"
  alias check-storage="$INSTALL_SCRIPTS/checks/hardware/storage.sh"
  alias check-users="$INSTALL_SCRIPTS/checks/system/users.sh"
  alias check-bootloader="$INSTALL_SCRIPTS/checks/system/bootloader.sh"
  alias check-locale="$INSTALL_SCRIPTS/checks/system/locale.sh"
  alias check-network="$INSTALL_SCRIPTS/checks/system/network.sh"

  # Utilities
  alias log="tail -f $INSTALL_LOG"
  alias clear-mounts="umount -R /mnt"
  alias restart-install="clear-mounts && rm -rf $INSTALL_TMP/* && clear"
  
  # Development Helpers
  alias edit-script="$EDITOR $INSTALL_SCRIPTS/"
  alias run-script="bash $INSTALL_SCRIPTS/"
  
  # Disk Management
  alias list-disks="${pkgs.util-linux}/bin/lsblk -f"
  alias show-partitions="${pkgs.util-linux}/bin/fdisk -l"
''