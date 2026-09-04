# Cross-module identity merge: former ssh-* modules → this module (systemConfig leaves).
# Discovered by ncc-module-migrate (plan-*.nix). Not single-module removeRelativePaths.
{ lib }: {
  id = "ssh-merge-v1";
  kind = "ssh-merge";
  description = "Merge ssh-server-manager + ssh-client-manager → ssh-manager";
  fromPaths = [
    "modules/security/ssh-server-manager"
    "modules/security/ssh-client-manager"
    # Pre-security layout leftover (monolith often kept this after merge)
    "modules/specialized/ssh-client-manager"
  ];
  # toPath optional — runner derives from this module's path under /etc/nixos
  # Obsolete leaf next to config.nix (hosts use ~/.creds for SSH client)
  removeObsoleteLeaves = [ "client-connections.nix" ];
}
