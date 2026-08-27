# Eval prebuild-check modules with stub specialArgs — catches missing imports at let-bind time.
{ pkgs, nixosRoot }:
let
  lib = pkgs.lib;
  inherit (lib) readDir;

  stubUi = {
    badges.success = s: "";
    badges.warning = s: "";
    badges.error = s: "";
    messages.info = s: "";
    messages.error = s: "";
    messages.loading = s: "";
  };

  stubApi = name:
    if name == "cli-registry" then {
      registerCommandsFor = _: _: [ ];
    } else if name == "cli-formatter" then stubUi
    else { };

  commonArgs = {
    inherit lib pkgs;
    config = { };
    systemConfig = { };
    getModuleConfig = _: { layout = "monolith"; };
    getModuleApi = stubApi;
  };

  scanDir = dir:
    let
      contents = readDir dir;
      files = lib.filter (n: lib.hasSuffix ".nix" n) (lib.attrNames contents);
      subdirs = lib.filter (n: contents.${n} == "directory") (lib.attrNames contents);
    in
      map (f: dir + "/${f}") files
      ++ lib.concatLists (map scanDir (map (d: dir + "/${d}") subdirs));

  prebuildRoot = "${nixosRoot}/core/management/system-manager/components/system-checks/prebuild/checks";
  modulePaths =
    if builtins.pathExists prebuildRoot then
      lib.filter (p:
        builtins.pathExists p && builtins.stringLength (builtins.readFile p) > 0
      ) (scanDir prebuildRoot)
    else [ ];

  evalOne = path:
    let
      attempt = builtins.tryEval (import path commonArgs);
    in {
      inherit path;
      ok = attempt.success;
      error = if attempt.success then null else attempt.value;
    };

  results = map evalOne modulePaths;
  failures = lib.filter (r: !r.ok) results;
in
{
  ok = failures == [ ];
  checked = map (r: r.path) results;
  errors = map (r: "${r.path}: ${r.error}") failures;
}
