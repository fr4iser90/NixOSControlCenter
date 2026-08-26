# Eval wrapper: load staged systemConfig/ and check against module options.nix.
{ pkgs, repoRoot, stagedRoot }:
let
  nixos = repoRoot + "/nixos";
  configsPath = stagedRoot + "/systemConfig";
  loader = import "${nixos}/core/management/system-manager/lib/config-loader.nix" { };
  systemConfig =
    loader.loadSystemConfig {
      flakeRoot = nixos;
      inherit configsPath;
      monolithPath = null;
      layout = "split";
    };
  result = import ./systemconfig-options-check.nix {
    inherit pkgs;
    nixosRoot = nixos;
    inherit systemConfig;
  };
in
{
  ok = result.ok;
  checked = result.checkedPaths;
  skipped = result.skipped;
  errors = result.errors or [];
}
