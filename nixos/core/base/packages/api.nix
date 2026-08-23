# Packages module API — catalog / installer feature export.
# Install-wizard (and peers) must use getModuleApi "packages", never relative
# imports into packages/lib.
{ lib, metadata, getModuleMetadata, getModuleApi, ... }:

let
  packageMeta = import ./lib/metadata.nix;
in
{
  # Set / recipe module metadata (packageModules names, groups, conflicts, …)
  inherit (packageMeta) modules;
  packageMetadata = packageMeta;

  # Bash snippet for install-wizard setup-options (ALL_FEATURES, groups, …)
  installerFeaturesBash = import ./lib/installer-features-bash.nix {
    inherit lib;
    metadata = packageMeta;
  };
}
