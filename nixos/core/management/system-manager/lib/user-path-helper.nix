# Utility: Generiert User-spezifische Pfade automatisch
{ systemConfig }:
let
  userCfg = systemConfig.core.base.user;
  firstUser = builtins.head (builtins.attrNames userCfg);
  userName = userCfg.${firstUser}.name or "user";
in "/home/${userName}/Documents/Git/NixOSControlCenter/nixos"