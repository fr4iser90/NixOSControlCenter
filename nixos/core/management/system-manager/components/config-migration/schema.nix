{ lib, ... }:

let
  utils = import ./utils.nix { inherit lib; };
  schemaDir = ./schema;
  migrationsDir = ./schema/migrations;
in

{
  # Auto-discovered schemas (no manual registration needed!)
  schemas = utils.discoverSchemas schemaDir;
  
  # Auto-discovered migration plans (no manual registration needed!)
  migrationPlans = utils.discoverMigrations migrationsDir;
  
  # Auto-generated migration paths (no manual definition needed!)
  migrationPaths = utils.generateMigrationPaths (utils.discoverMigrations migrationsDir);
  
  # Current version (only thing that needs manual update when releasing new version)
  currentVersion = "1.0";
  
  # Minimum supported version (lowest version in discovered schemas)
  minSupportedVersion = 
    let
      versions = lib.attrNames (utils.discoverSchemas schemaDir);
      # Sort versions by converting to float and comparing
      versionToFloat = v: 
        let parts = lib.splitString "." v;
            major = lib.toInt (lib.elemAt parts 0);
            minor = lib.toInt (lib.elemAt parts 1);
        in major * 1000 + minor;
      sorted = lib.sort (a: b: (versionToFloat a) < (versionToFloat b)) versions;
    in
      if sorted == [] then "1.0" else lib.head sorted;
  
  # Helper functions
  
  # Get schema for specific version
  getSchema = version: 
    let schemas = utils.discoverSchemas schemaDir;
    in schemas.${version} or null;
  
  # Check if version is supported
  isVersionSupported = version: 
    lib.hasAttr version (utils.discoverSchemas schemaDir);
  
  # Check if direct migration exists (v1→v2)
  canMigrate = fromVersion: toVersion:
    let
      plans = utils.discoverMigrations migrationsDir;
    in
      lib.hasAttr fromVersion plans && 
      lib.hasAttr toVersion plans.${fromVersion};
  
  # Find migration chain (v1→v4 = v1→v2→v3→v4)
  findMigrationChain = fromVersion: toVersion:
    utils.findMigrationChain (utils.discoverMigrations migrationsDir) fromVersion toVersion;
  
  # Check if migration chain exists
  canMigrateChain = fromVersion: toVersion:
    utils.canMigrateChain (utils.discoverMigrations migrationsDir) fromVersion toVersion;
}
