# Cross-module rename: former homelab-manager → this module (systemConfig leaf).
# Discovered by ncc-module-migrate (plan-*.nix).
{ lib }: {
  id = "stack-manager-rename-v1";
  kind = "rename";
  description = "Rename homelab-manager → stack-manager (homelab + compute catalogs)";
  fromPaths = [ "modules/infrastructure/homelab-manager" ];
}
