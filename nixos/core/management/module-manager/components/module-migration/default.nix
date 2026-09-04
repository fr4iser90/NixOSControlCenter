{ pkgs, lib, getModuleApi, getModuleMetadata }:

let
  runner = import ./runner.nix { inherit pkgs lib getModuleApi getModuleMetadata; };
in {
  inherit (runner) moduleMigrate;
  # Deprecated empty registry — plans discovered from <module>/migrations/plan-*.nix
  plans = runner.plans;
  migrate = runner.moduleMigrate;
}
