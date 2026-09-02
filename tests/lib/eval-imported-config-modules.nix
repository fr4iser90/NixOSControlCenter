# Eval `import ./config.nix { … }` fragments the same way NixOS loads them into
# `imports` — catches illegal top-level mkMerge and mixed `config` + shorthand
# (e.g. warnings) that only fail at full system eval.
#
# Why gates missed this before: validate-nix-module-eval only imported
# prebuild-check scripts, not module config.nix values placed in imports.
{ pkgs, nixosRoot }:
let
  lib = pkgs.lib;

  getModuleConfig = name:
    if name == "desktop" then {
      enable = true;
      environment = "plasma";
    } else if name == "localization" then {
      keyboardLayout = "us";
      keyboardOptions = "";
    } else if name == "system-manager" then {
      layout = "monolith";
      allowUnfree = true;
    } else {
      enable = false;
      layout = "monolith";
      system = "none";
    };

  defaultsFor = path: moduleName: {
    inherit lib pkgs;
    config = { };
    systemConfig = { };
    inherit getModuleConfig;
    getModuleApi = name:
      if name == "packages" then { modules = { }; }
      else if name == "cli-formatter" then {
        text = { header = _: ""; };
        messages = { info = _: ""; error = _: ""; loading = _: ""; success = _: ""; };
        badges = { success = _: ""; warning = _: ""; error = _: ""; };
      }
      else { };
    getModuleMetadata = _: { path = dirOf path; };
    getCurrentModuleMetadata = _: {
      configPath = "core.base.${moduleName}";
      path = dirOf path;
    };
    inherit moduleName;
  };

  callConfig = path:
    let
      moduleName = builtins.baseNameOf (dirOf path);
      f = import path;
      formal = builtins.functionArgs f;
      base = defaultsFor path moduleName;
      args = lib.genAttrs (lib.attrNames formal) (n: base.${n} or null);
    in
      f args;

  # Paths of config.nix files that parent default.nix loads via (import ./config.nix …).
  configPaths = lib.filter builtins.pathExists [
    "${nixosRoot}/core/base/desktop/config.nix"
    "${nixosRoot}/core/base/boot/config.nix"
    "${nixosRoot}/core/base/audio/config.nix"
    "${nixosRoot}/core/base/hardware/config.nix"
    "${nixosRoot}/core/base/localization/config.nix"
    "${nixosRoot}/core/base/network/config.nix"
    "${nixosRoot}/core/base/packages/config.nix"
    # user/cli-* need heavier stubs; still shape-check via call + eval when possible
    "${nixosRoot}/core/base/user/config.nix"
    "${nixosRoot}/core/management/cli-registry/config.nix"
    "${nixosRoot}/core/management/tui-engine/config.nix"
  ];

  loadAsModule = path:
    let
      imported = callConfig path;
      eval = lib.evalModules {
        modules = [
          { _module.check = false; }
          imported
        ];
      };
    in
      builtins.deepSeq eval.config true;

  classify = path:
    let
      imp = builtins.tryEval (callConfig path);
    in
      if !imp.success then "import-failed"
      else if builtins.isAttrs imp.value && (imp.value._type or null) == "merge" then
        "top-level-mkMerge-not-a-module"
      else if builtins.isAttrs imp.value && !(imp.value ? _type)
           && (imp.value ? config || imp.value ? options)
           && (builtins.length (builtins.attrNames (lib.removeAttrs imp.value [
                "config" "options" "imports" "_module" "_file" "key" "disabledModules"
              ]))) > 0 then
        "mixed-config-and-shorthand"
      else
        "evalModules-rejected";

  evalOne = path:
    let
      attempt = builtins.tryEval (loadAsModule path);
    in {
      inherit path;
      ok = attempt.success;
      kind = if attempt.success then "ok" else classify path;
    };

  results = map evalOne configPaths;
  failures = lib.filter (r: !r.ok) results;
in
{
  ok = failures == [ ];
  checked = map (r: r.path) results;
  errors = map (r:
    "${r.path}: ${r.kind} — illegal as imports= module (never top-level lib.mkMerge; with explicit config=, put warnings/assertions inside config)"
  ) failures;
}
