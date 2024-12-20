# app/shell/install/hooks/info.nix
{ pkgs }:

''
  # Funktion für Hilfe-Anzeige
  function show-help() {
    echo ""
    echo "Available Commands:"
    echo "----------------"
    echo "Installation:"
    echo "  install-basic      - Interactive basic installation"
    echo "  install-minimal    - Minimal installation (no prompts)"
    echo ""
    echo "Profiles:"
    echo "  install-desktop    - Desktop environment"
    echo "  install-server     - Server configuration"
    echo "  install-dev        - Development setup"
    echo "  install-gaming     - Gaming optimized"
    echo ""
    echo "System Checks:"
    echo "  check-hardware     - Verify hardware compatibility"
    echo "  check-network     - Test network connection"
    echo "  check-disk        - Check disk configuration"
    echo "  check-efi         - Verify EFI/BIOS setup"
    echo "  check-all         - Run all checks"
    echo ""
    echo "Disk Management:"
    echo "  list-disks        - Show available disks"
    echo "  create-partitions - Create default partitions"
    echo "  mount-system      - Mount partitions for install"
    echo ""
    echo "Configuration:"
    echo "  show-config       - Display current config"
    echo "  edit-config       - Edit configuration"
    echo "  backup-config     - Backup configuration"
    echo ""
    echo "Type 'show-env' to see environment variables"
  }

  # Funktion für Umgebungsvariablen-Anzeige
  function show-env() {
    echo ""
    echo "Environment Variables:"
    echo "--------------------"
    echo "Installation:"
    echo "  NIXOS_CONFIG:     $NIXOS_CONFIG"
    echo "  INSTALL_MODE:     $INSTALL_MODE"
    echo "  INSTALL_PROFILE:  $INSTALL_PROFILE"
    echo ""
    echo "System:"
    echo "  ROOT_DISK:        $ROOT_DISK"
    echo "  BOOT_MODE:        $BOOT_MODE"
    echo "  HOSTNAME:         $HOSTNAME"
    echo ""
    echo "Paths:"
    echo "  MOUNT_POINT:      $MOUNT_POINT"
    echo "  CONFIG_BACKUP:    $CONFIG_BACKUP"
    echo ""
  }

  # Zeige initial keine Info - nur Welcome
  # show-help
''