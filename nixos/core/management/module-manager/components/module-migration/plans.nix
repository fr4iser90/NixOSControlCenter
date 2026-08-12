# Module migration plans (rename / merge / orphan cleanup).
# Applied by ncc-module-migrate; tracked in systemConfig/.ncc-module-migrations.json
{ lib }:

{
  plans = [
    {
      id = "ssh-merge-v1";
      description = "Merge ssh-server-manager + ssh-client-manager → ssh-manager";
      fromPaths = [
        "modules/security/ssh-server-manager"
        "modules/security/ssh-client-manager"
      ];
      toPath = "modules/security/ssh-manager";
      kind = "ssh-merge"; # runner dispatch
    }
  ];
}
