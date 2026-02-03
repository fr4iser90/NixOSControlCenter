{ lib, ... }:

let
  # Scan modules/ subdirectories
  contents = builtins.readDir ./.;
  
  # Find directories with modules (recursive scan)
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
  
  allModulePaths = findModules ./.;
in
{
  imports = allModulePaths;
}
