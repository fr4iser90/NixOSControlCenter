# Module Discovery Logic - FULLY AUTOMATIC
{ lib, ... }:

let
  # Use absolute paths from flake root
  flakeRoot = ../../../..;

  # Discover all domains in modules/ directory
  discoverDomains = let
    modulesDir = "${flakeRoot}/modules";
  in if builtins.pathExists modulesDir then
    # All subdirectories are potential domains
    lib.filterAttrs (name: type: type == "directory") (builtins.readDir modulesDir)
  else {};

  # Discover all modules within a domain
  discoverModulesInDomain = domainName: let
    domainDir = "${flakeRoot}/modules/${domainName}";
    contents = builtins.readDir domainDir;
  in lib.flatten (
    lib.mapAttrsToList (name: type:
      if type == "directory" then
        let
          moduleDir = "${domainDir}/${name}";
          hasDefault = builtins.pathExists "${moduleDir}/default.nix";
          hasOptions = builtins.pathExists "${moduleDir}/options.nix";
        in if hasDefault && hasOptions then
          let
            # Read module metadata if available
            metadata = if builtins.pathExists "${moduleDir}/metadata.nix"
              then import "${moduleDir}/metadata.nix"
              else {};

            # Determine category based on domain
            category = domainName;

            # Generate API paths automatically
            configPath = "systemConfig.${category}.${name}";
            enablePath = "${configPath}.enable";
            apiPath = "config.core.${category}.${name}";
          in [{
            name = name;
            domain = domainName;
            category = category;
            path = moduleDir;
            configPath = configPath;
            enablePath = enablePath;
            apiPath = apiPath;
            configFile = "/etc/nixos/configs/${name}-config.nix";
            description = metadata.description or "${name} module";
            dependencies = metadata.dependencies or [];
            version = metadata.version or "1.0";
            defaultEnabled = false; # Features are disabled by default
          }]
        else []
      else []
    ) contents
  );

  # Discover core modules (always active)
  discoverCoreModules = let
    coreDir = "${flakeRoot}/core";
    contents = builtins.readDir coreDir;
  in lib.flatten (
    lib.mapAttrsToList (name: type:
      if type == "directory" && name != "modules" then
        let
          moduleDir = "${coreDir}/${name}";
          hasDefault = builtins.pathExists "${moduleDir}/default.nix";
        in if hasDefault then [{
          name = name;
          domain = "core";
          category = "core";
          path = moduleDir;
          configPath = "systemConfig.core.${name}";
          enablePath = "systemConfig.core.${name}.enable";
          apiPath = "config.core.${name}";
          configFile = "/etc/nixos/configs/${name}-config.nix";
          description = "Core ${name} module";
          dependencies = [];
          version = "1.0";
          defaultEnabled = true; # Core modules enabled by default
        }] else []
      else []
    ) contents
  );

  # Discover all modules (core + features)
  discoverAllModules = let
    domainModules = lib.flatten (
      lib.mapAttrsToList (domainName: _:
        discoverModulesInDomain domainName
      ) discoverDomains
    );
    coreModules = discoverCoreModules;
  in coreModules ++ domainModules;

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

      # Module status
      isEnabled = module.defaultEnabled;
      configPath = module.configPath;
    };

    # Generate API for a domain (collection of modules)
    generateDomainAPI = domainName: modulesInDomain: {
      modules = lib.listToAttrs (
        map (module: {
          name = module.name;
          value = generateModuleAPI module;
        }) modulesInDomain
      );

      # Domain-level utilities
      enabledModules = lib.filter (m: m.isEnabled) modulesInDomain;
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
  inherit discoverAllModules discoverDomains discoverModulesInDomain discoverCoreModules generateAPIs resolveDependencies;

  # Convenience function: Discover modules and generate APIs
  discoverAndGenerateAPIs = let
    allModules = discoverAllModules;
    resolvedModules = resolveDependencies allModules;
  in generateAPIs resolvedModules;
}
