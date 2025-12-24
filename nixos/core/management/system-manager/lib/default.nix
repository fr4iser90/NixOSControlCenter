# Library exports for system-manager
# Note: homelab-utils.nix has been moved to modules/homelab-manager/lib/

rec {
  # Version management helpers (for module version checking)
  version-helpers = import ./version-helpers.nix;
  
  # Backup helpers (centralized backup functionality)
  backup-helpers = import ./backup-helpers.nix;

  # Config migration helpers
  config-migration = import ../components/config-migration/migration.nix;
}
