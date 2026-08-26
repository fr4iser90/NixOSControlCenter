# Validate a loaded systemConfig attrset against discovered module options.nix types.
# Used by tests/validate-systemconfig-writes.sh (install-wizard staged config).
{ pkgs, nixosRoot, systemConfig }:
let
  lib = pkgs.lib;
  discovery = import "${nixosRoot}/core/management/module-manager/lib/discovery.nix" { inherit lib; };
  allModules = discovery.discoverAllModules;

  # Modules install-wizard / config-writer can populate (avoid heavy optional trees).
  wizardModules = [
    "hardware"
    "desktop"
    "packages"
    "localization"
    "network"
    "user"
    "system-manager"
    "audio"
    "stack-manager"
    "ssh-manager"
    "ai-workspace"
    "bootentry-manager"
    "vm"
    "lock-manager"
    "overrides"
  ];

  getCurrentModuleMetadata = modulePath:
    let
      moduleName = builtins.baseNameOf (toString modulePath);
      matching = lib.filter (m: m.name == moduleName) allModules;
    in
      if matching == [] then {
        name = moduleName;
        path = modulePath;
        configPath = "modules.${moduleName}";
        enablePath = "modules.${moduleName}.enable";
        apiPath = "modules.${moduleName}";
        category = "modules.${moduleName}";
      } else
        lib.head matching;

  importArgsMinimal = m: {
    inherit lib;
    moduleName = m.name;
    getCurrentModuleMetadata = getCurrentModuleMetadata;
  };

  importArgsExtended = m:
    importArgsMinimal m // {
      pkgs = pkgs;
      metadata = m;
      config = { };
      systemConfig = systemConfig;
      getModuleConfig = _: { };
      getModuleApi = _: { };
      getModuleMetadata = getCurrentModuleMetadata;
      moduleConfig = { getModuleConfig = _: { }; };
    };

  modulesWithOptions =
    lib.filter (m: builtins.elem m.name wizardModules && builtins.pathExists "${m.path}/options.nix")
    allModules;

  moduleHasUserConfig = m:
    let
      v = lib.attrByPath (lib.splitString "." m.configPath) { } systemConfig;
    in
      v != { } && v != null;

  modulesToCheck = lib.filter moduleHasUserConfig modulesWithOptions;

  configForEval = {
    config = systemConfig // {
      systemConfig = systemConfig;
    };
  };

  validateOne = m:
    let
      modPath = "${m.path}/options.nix";
      needsExtended = !(builtins.tryEval (import modPath (importArgsMinimal m))).success;
      specialArgs = if needsExtended then importArgsExtended m else importArgsMinimal m;
      evalAttempt = builtins.tryEval (lib.evalModules {
        modules = [
          (import modPath)
          configForEval
        ];
        inherit specialArgs;
      });
    in {
      path = m.configPath;
      ok = evalAttempt.success;
      error = if evalAttempt.success then null else (evalAttempt.value);
    };

  results = map validateOne modulesToCheck;
  failures = lib.filter (r: !r.ok) results;
  skipped = [ ];
  checkedPaths = map (r: r.path) (lib.filter (r: r.ok) results);
in
{
  ok = failures == [];
  inherit checkedPaths skipped;
  errors = map (r: "${r.path}: ${r.error}") failures;
}
