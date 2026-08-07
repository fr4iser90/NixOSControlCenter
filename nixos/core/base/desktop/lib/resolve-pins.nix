{ lib, pinMap }:

{
  # pinnedApps: explicit list (wins when non-empty)
  # pinnedAppsAuto: derive from packages/modules when pinnedApps == []
  # packageModules / systemPackages: from packages module
  # environment: plasma | gnome | xfce
  pinnedApps,
  pinnedAppsAuto,
  packageModules,
  systemPackages,
  userPackagesFlat,
  environment,
}:
let
  fromPackages = lib.concatMap (pkg: pinMap.packages.${pkg} or []) (
    systemPackages ++ userPackagesFlat
  );

  fromModules = lib.concatMap (mod: pinMap.modules.${mod} or []) packageModules;

  defaults = pinMap.defaultsByEnv.${environment} or [];

  derived =
    if pinnedAppsAuto then
      lib.unique (fromPackages ++ fromModules ++ defaults)
    else
      [];

  effective =
    if pinnedApps != [] then lib.unique pinnedApps
    else derived;
in
effective
