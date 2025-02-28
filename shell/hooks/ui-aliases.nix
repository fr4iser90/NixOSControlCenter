{ pkgs }:
''
  # Hauptinstallation
  alias install="$CORE_DIR/init.sh"
  
  # Quick-Install Befehle
  install-quick-gaming() {
    local modules=""
    for mod in "$@"; do
      case "$mod" in
        +streaming) modules="$modules --streaming" ;;
        +emulation) modules="$modules --emulation" ;;
      esac
    done
    $MODES_DIR/gaming-setup.sh $modules
  }

  install-quick-server() {
    local modules=""
    for mod in "$@"; do
      case "$mod" in
        +docker) modules="$modules --docker" ;;
        +web) modules="$modules --web" ;;
      esac
    done
    $MODES_DIR/server-setup.sh $modules
  }

  # Alternative Install-Modi
  alias install-workstation="$MODES_DIR/workstation-setup.sh"
  alias install-homelab="$HOMELAB_DIR/homelab-setup.sh"
  
  # Setup-Varianten
  alias setup-predefined="$MODES_DIR/predefinedSetup.sh"
  alias setup-personalized="$MODES_DIR/personalizedSetup.sh"

  # System Checks
  alias check-gpu="$CHECKS_DIR/hardware/gpu.sh"
  alias check-cpu="$CHECKS_DIR/hardware/cpu.sh"
  alias check-memory="$CHECKS_DIR/hardware/memory.sh"
  alias check-storage="$CHECKS_DIR/hardware/storage.sh"
  alias check-users="$CHECKS_DIR/system/users.sh"
  alias check-bootloader="$CHECKS_DIR/system/bootloader.sh"
  alias check-locale="$CHECKS_DIR/system/locale.sh"
  alias check-network="$CHECKS_DIR/system/network.sh"

  # Utilities
  alias log="tail -f $INSTALL_LOG"
  alias clear-mounts="umount -R /mnt"
  alias restart-install="clear-mounts && rm -rf $INSTALL_TMP/* && clear"
  
  # Development Helpers
  alias edit-script="$EDITOR $SCRIPT_ROOT/"
  alias run-script="bash $SCRIPT_ROOT/"
  
  # Disk Management
  alias list-disks="${pkgs.util-linux}/bin/lsblk -f"
  alias show-partitions="${pkgs.util-linux}/bin/fdisk -l"
''