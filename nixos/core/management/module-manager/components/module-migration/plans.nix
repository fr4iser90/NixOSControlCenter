# DEPRECATED empty registry — cross-module rename/merge plans live in
#   <destination-module>/migrations/plan-*.nix
# and are discovered by ncc-module-migrate. Do not add fromPaths/toPath here.
{ lib }: {
  plans = [];
}
