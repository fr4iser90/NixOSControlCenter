# Map modules/<…>/<name>/ → { <name> = path; } for flake nixosModules exports.
# Same rule as modules/default.nix: directory with default.nix + options.nix.
{ lib, modulesDir }:
let
  findModules = dir:
    let
      items = builtins.readDir dir;
    in
      lib.flatten (lib.mapAttrsToList (name: type:
        if type == "directory" then
          let
            subdir = dir + "/${name}";
            hasDefault = builtins.pathExists "${subdir}/default.nix";
            hasOptions = builtins.pathExists "${subdir}/options.nix";
          in
            if hasDefault && hasOptions
            then [ subdir ]
            else findModules subdir
        else []
      ) items);

  paths = findModules modulesDir;
in
  lib.listToAttrs (map (p: {
    name = baseNameOf p;
    value = p;
  }) paths)
