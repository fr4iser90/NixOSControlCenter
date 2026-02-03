# Module Discovery Logic - FULLY AUTOMATIC
{ lib, ... }:

let
  # Use absolute paths from flake root
  flakeRoot = ../../../..;

  # Discover modules in modules/ directory (recursive)
  discoverModulesModules = discoverModulesRecursively "${flakeRoot}/modules" "modules";
  # Strucuture 
  # flakeRoot/core/moduledomain/module-name/submodules/submodule-a
  # flakeRoot/modules/moduledomain/module-name/submodules/submodule-a
  # Discover modules recursively in a directory
  discoverModulesRecursively = rootDir: domain: let
    scanDir = dir: category: let
      contents = builtins.readDir dir;
  in lib.flatten (
    lib.mapAttrsToList (moduleName: type:
      if type == "directory" then
        let
            subDir = "${dir}/${moduleName}";
            hasDefault = builtins.pathExists "${subDir}/default.nix";
            hasOptions = builtins.pathExists "${subDir}/options.nix";
            currentCategory = if category == "" then moduleName else "${category}.${moduleName}";
        in if hasDefault && hasOptions then
            # Found a module!
            [{
            name = moduleName;
              domain = domain;
              category = "${domain}.${currentCategory}";
              path = subDir;
              configPath = "${domain}.${currentCategory}";
              enablePath = "${domain}.${currentCategory}.enable";
              apiPath = "${domain}.${currentCategory}";
              configFile = "/etc/nixos/configs/${domain}/${category}/${moduleName}/config.nix";
              description = "${domain} ${currentCategory} module";
              dependencies = [];
              version = "1.0";
              defaultEnabled = domain == "core"; # Core modules enabled by default
          }]
            # Continue scanning deeper
            ++ scanDir subDir currentCategory
          else
            # Not a module, but continue scanning
            scanDir subDir currentCategory
      else []
    ) contents
  );
  in scanDir rootDir "";

  # Discover core modules (always active) - now recursive!
  discoverCoreModules = discoverModulesRecursively "${flakeRoot}/core" "core";

  # Discover all modules (core + modules) - both recursive now!
  discoverAllModules = discoverCoreModules ++ discoverModulesModules;

  # Generate automatic APIs for all discovered modules
  generateAPIs = modules: let
    # Group modules by domain for cleaner API structure
    modulesByDomain = lib.groupBy (m: m.domain) modules;

    # Generate API for a single module
    generateModuleAPI = module: let
      modulePath = module.path;
      hasLib = builtins.pathExists "${modulePath}/lib/default.nix";
      hasCommands = builtins.pathExists "${modulePath}/commands.nix";
    in {
      # Basic module info
      name = module.name;
      version = module.version;
      description = module.description;

      # Conditional exports based on what the module provides
      lib = if hasLib then import "${modulePath}/lib/default.nix" else {};
      commands = if hasCommands then import "${modulePath}/commands.nix" else {};
      api = {}; # Module API - can be extended by the module itself

      # Module status
      isEnabled = module.defaultEnabled;
      configPath = module.configPath;
    };

    # Generate API for a domain (collection of modules)
    generateDomainAPI = domainName: modulesInDomain: let
      moduleAPIs = lib.listToAttrs (
        map (module: {
          name = module.name;
          value = generateModuleAPI module;
        }) modulesInDomain
      );
    in {
      modules = moduleAPIs;

      # Domain-level utilities
      enabledModules = lib.mapAttrsToList (name: api: api) (lib.filterAttrs (name: api: api.isEnabled) moduleAPIs);
      allModules = modulesInDomain;
    };

  in {
    # Top-level API structure: core.{domain}.{module}
    core = lib.mapAttrs generateDomainAPI modulesByDomain;
  };

  # Resolve module dependencies automatically
  resolveDependencies = modules: let
    moduleMap = lib.listToAttrs (
      map (m: { name = m.name; value = m; }) modules
    );

    # Check if all dependencies of a module are available
    checkDependencies = module: dependencies:
      lib.all (dep: moduleMap ? ${dep}) dependencies;

    # Sort modules by dependency (simple topological sort)
    sortedModules = lib.toposort (a: b:
      # a depends on b if b is in a's dependencies
      lib.elem b.name a.dependencies
    ) modules;

    # Only include modules whose dependencies are satisfied
    validModules = lib.filter (module:
      checkDependencies module module.dependencies
    ) sortedModules.result;

  in validModules;

in {
  inherit discoverAllModules discoverCoreModules discoverModulesModules discoverModulesRecursively generateAPIs resolveDependencies;

  # Convenience function: Discover modules and generate APIs
  discoverAndGenerateAPIs = let
    allModules = discoverAllModules;
    resolvedModules = resolveDependencies allModules;
  in generateAPIs resolvedModules;
}
