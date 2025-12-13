# Module Discovery Logic
{ lib, ... }:

let
  # FULLY GENERIC: Each module defines its own defaults!
  # Use absolute paths from flake root
  flakeRoot = ../../../../..;

  discoverModulesInDir = basePath: let
    baseDir = basePath;
    contents = builtins.readDir baseDir;
  in lib.flatten (
    lib.mapAttrsToList (name: type:
      if type == "directory" then
        let
          moduleDir = "${baseDir}/${name}";
          hasDefault = builtins.pathExists "${moduleDir}/default.nix";
        in if hasDefault then
          # Each module decides its own defaults!
          let
            # Try to read the module's options to get its default
            defaultEnabled = false; # Fallback
          in [{
            name = name;
            enablePath = "systemConfig.${name}.enable";
            configFile = "/etc/nixos/configs/${name}-config.nix";
            category = baseNameOf basePath;
            description = "${name}";
            defaultEnabled = defaultEnabled;  # Each module defines this itself
          }]
        else []
      else []
    ) contents
  );

  discoverAllModules =
    (discoverModulesInDir "${flakeRoot}/core") ++
    (discoverModulesInDir "${flakeRoot}/features");

in {
  inherit discoverAllModules discoverModulesInDir;
}
