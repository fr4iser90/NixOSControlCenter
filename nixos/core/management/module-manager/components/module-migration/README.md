# Module migration — rename/merge/orphan cleanup for module configs
#
# Parallel to system-manager config-migration (layout schema), but for
# module IDs and their systemConfig leaves.
#
# Pipeline (coupled):
#   ncc-config-check
#     → legacy configs/ cleanup
#     → schema validate / migrate-config
#     → ncc-module-migrate   (plans + orphan cleanup)
#
#   ncc system update (after rebuild)
#     → ncc-migrate-config
#     → ncc-module-migrate
#
# CLI:
#   ncc modules migrate [--dry-run] [--verbose] [--skip-orphans]
#   ncc-module-migrate
#
# Orphans (split layout):
#   Removes systemConfig/{core,modules}/**/config.nix with no matching
#   discovered module. Never touches:
#     - /etc/nixos/custom/          (userspace NixOS modules)
#     - systemConfig/users/         (per-user leaves)
#     - systemConfig/custom/        (if present)
#
# Monolith:
#   Named plans (e.g. ssh-merge) still apply. Generic orphan walk skipped
#   (nested enable flags would false-positive).
#
# State: /etc/nixos/systemConfig/.ncc-module-migrations.json
#
# First plan: ssh-merge-v1 (ssh-server-manager + ssh-client-manager → ssh-manager)
# Second: stack-manager-rename-v1 (homelab-manager → stack-manager)
