# Module migration plans (rename / merge / orphan cleanup).
# Applied by ncc-module-migrate; tracked in /var/lib/ncc/module-migrations.json
{ lib }:

{
  plans = [
    {
      id = "ssh-merge-v1";
      description = "Merge ssh-server-manager + ssh-client-manager → ssh-manager";
      fromPaths = [
        "modules/security/ssh-server-manager"
        "modules/security/ssh-client-manager"
        # Pre-security layout leftover (monolith often kept this after merge)
        "modules/specialized/ssh-client-manager"
      ];
      toPath = "modules/security/ssh-manager";
      kind = "ssh-merge";
    }
    {
      id = "stack-manager-rename-v1";
      description = "Rename homelab-manager → stack-manager (homelab + compute catalogs)";
      fromPaths = [ "modules/infrastructure/homelab-manager" ];
      toPath = "modules/infrastructure/stack-manager";
      kind = "rename";
    }
  ];
}
