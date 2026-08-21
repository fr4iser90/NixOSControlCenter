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
#     - systemConfig/users/         (per-user leaves, split only)
#     - systemConfig/custom/        (if present)
#
# Monolith:
#   Named plans (e.g. ssh-merge) still apply. Generic orphan walk skipped
#   (nested enable flags would false-positive).
#   SSOT is systemConfig.nix only (incl. users.*). No hybrid systemConfig/ tree.
#
# State: /var/lib/ncc/module-migrations.json
# (legacy path systemConfig/.ncc-module-migrations.json is moved on scrub/migrate)
# Applied plan IDs only — never write `_migratedFrom` / `_version` into user leaves
#
# First plan: ssh-merge-v1 (ssh-server-manager + ssh-client-manager → ssh-manager;
#   also drops leftover modules/specialized/ssh-client-manager)
# Second: stack-manager-rename-v1 (homelab-manager → stack-manager)
#
# User-facing leaf example after rename:
#   modules.infrastructure.stack-manager = { enable = true; …user overrides… };
# Template/options supply defaults (catalog URL, empty profiles) via getModuleConfig — not by dumping meta into systemConfig.
