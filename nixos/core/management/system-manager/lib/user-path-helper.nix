# Utility: first configured user's NCC nixos checkout path
{ getModuleConfig }:
let
  userCfg = getModuleConfig "user";
  names = builtins.attrNames (builtins.removeAttrs userCfg [ "enable" ]);
  # Prefer attr names that look like usernames (attrs with role)
  userNames = builtins.filter (n: builtins.isAttrs (userCfg.${n} or null)) names;
  firstUser = if userNames == [] then "root" else builtins.head userNames;
in
  "/home/${firstUser}/Documents/Git/NixOSControlCenter/nixos"
