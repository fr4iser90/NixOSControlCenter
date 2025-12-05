{ lib, ... }:

rec {
  # Extract version number from filename (e.g., "v1.nix" -> "1.0")
  extractVersion = filename:
    let
      # Remove .nix extension
      base = lib.removeSuffix ".nix" filename;
      # Remove 'v' prefix
      versionStr = lib.removePrefix "v" base;
      # Convert to version format (e.g., "1" -> "1.0", "1.2" -> "1.2")
      parts = lib.splitString "." versionStr;
    in
      if lib.length parts == 1 then
        "${lib.head parts}.0"
      else
        versionStr;

  # Parse migration filename (e.g., "v1-to-v2.nix" -> { from = "1.0"; to = "2.0"; })
  parseMigrationFilename = filename:
    let
      base = lib.removeSuffix ".nix" filename;
      parts = lib.splitString "-to-" base;
      fromPart = lib.removePrefix "v" (lib.head parts);
      toPart = lib.removePrefix "v" (lib.elemAt parts 1);
      fromVersion = if lib.length (lib.splitString "." fromPart) == 1 then "${fromPart}.0" else fromPart;
      toVersion = if lib.length (lib.splitString "." toPart) == 1 then "${toPart}.0" else toPart;
    in
      { from = fromVersion; to = toVersion; };

  # Discover all schema files in directory
  discoverSchemas = schemaDir:
    let
      files = builtins.readDir schemaDir;
      schemaFiles = lib.filterAttrs (name: type: 
        type == "regular" && 
        lib.hasPrefix "v" name && 
        lib.hasSuffix ".nix" name &&
        name != "default.nix"
      ) files;
      loadSchema = name: version: import (schemaDir + "/${name}") { inherit lib; };
    in
      lib.mapAttrs' (name: _: 
        lib.nameValuePair (extractVersion name) (loadSchema name (extractVersion name))
      ) schemaFiles;

  # Discover all migration files in directory
  discoverMigrations = migrationsDir:
    let
      files = builtins.readDir migrationsDir;
      migrationFiles = lib.filterAttrs (name: type:
        type == "regular" &&
        lib.hasPrefix "v" name &&
        lib.hasSuffix ".nix" name &&
        lib.hasInfix "-to-" name
      ) files;
      loadMigration = name: import (migrationsDir + "/${name}") { inherit lib; };
      parseAndLoad = name:
        let parsed = parseMigrationFilename name;
        in { from = parsed.from; to = parsed.to; plan = loadMigration name; };
      migrations = map parseAndLoad (lib.attrNames migrationFiles);
    in
      lib.foldl' (acc: m:
        lib.recursiveUpdate acc {
          ${m.from} = {
            ${m.to} = m.plan;
          };
        }
      ) {} migrations;

  # Generate migration paths from migration plans
  # Creates direct paths (v1→v2) and can be extended for chain resolution
  generateMigrationPaths = migrationPlans:
    lib.mapAttrs (fromVersion: toVersions:
      # For now, take first available migration (direct path)
      # Chain resolution will be handled by findMigrationChain
      lib.head (lib.attrNames toVersions)
    ) migrationPlans;

  # Find migration chain from source to target version
  # Returns list of versions to migrate through: [from, intermediate..., to]
  findMigrationChain = migrationPlans: fromVersion: toVersion:
    let
      # Build graph of available migrations
      graph = lib.mapAttrs (from: toVersions:
        lib.attrNames toVersions
      ) migrationPlans;
      
      # BFS to find path
      findPath = current: target: visited: path:
        if current == target then
          lib.reverseList path
        else if lib.elem current visited then
          null
        else
          let
            nextVersions = graph.${current} or [];
            newVisited = visited ++ [ current ];
            newPath = [ current ] ++ path;
            results = map (next: findPath next target newVisited newPath) nextVersions;
            validPaths = lib.filter (p: p != null) results;
          in
            if validPaths == [] then null else lib.head validPaths;
    in
      findPath fromVersion toVersion [] [];

  # Check if migration chain exists
  canMigrateChain = migrationPlans: fromVersion: toVersion:
    findMigrationChain migrationPlans fromVersion toVersion != null;
}

