# Layout detection and path helpers for systemConfig dual layout (v2)
# Layouts:
#   monolith → /etc/nixos/systemConfig.nix  (nested attrset, same shape as in-memory)
#   split    → /etc/nixos/systemConfig/**/config.nix
{ }:

let
  pathExists = path:
    let result = builtins.tryEval (builtins.pathExists path);
    in result.success && result.value;

  readDir = path:
    let result = builtins.tryEval (builtins.readDir path);
    in if result.success then result.value else {};

  # Absolute runtime paths (NixOS install)
  nixosRoot = "/etc/nixos";
  monolithFileName = "systemConfig.nix";
  splitDirName = "systemConfig";

  absolute = {
    root = nixosRoot;
    monolith = "${nixosRoot}/${monolithFileName}";
    split = "${nixosRoot}/${splitDirName}";
  };

  # Convert dotted or slash module path to list: "core.base.hardware" | "core/base/hardware" → ["core" "base" "hardware"]
  pathToList = modulePath:
    let
      normalized = builtins.replaceStrings [ "." ] [ "/" ] modulePath;
      parts = builtins.filter (p: builtins.isString p && p != "")
        (builtins.split "/" normalized);
    in
      parts;

  listToSlash = parts: builtins.concatStringsSep "/" parts;
  listToDots = parts: builtins.concatStringsSep "." parts;

  # Split leaf path for a module
  splitConfigFile = modulePath:
    "${absolute.split}/${listToSlash (pathToList modulePath)}/config.nix";

  # Recursively check if any config.nix exists under a directory
  hasSplitConfigs = configsPath:
    let
      findConfigs = currentDir:
        let
          dir = readDir currentDir;
          names = builtins.attrNames dir;
          hasConfig = builtins.elem "config.nix" names && dir."config.nix" == "regular";
          subDirs = builtins.filter (n: dir.${n} == "directory") names;
        in
          hasConfig || builtins.any (d: findConfigs (currentDir + "/${d}")) subDirs;
    in
      pathExists configsPath && findConfigs configsPath;

  # Detect layout from paths (flake-relative or absolute)
  # Prefer explicit layout field when loading monolith/split content separately
  detectLayoutFromPaths = { monolithPath, configsPath, defaultLayout }:
    let
      hasMonolith = monolithPath != null && pathExists monolithPath;
      hasSplit = configsPath != null && hasSplitConfigs configsPath;
    in
      if hasMonolith && !hasSplit then "monolith"
      else if hasSplit && !hasMonolith then "split"
      else if hasMonolith && hasSplit then
        # Ambiguous: prefer explicit layout inside monolith if present
        let
          mono = import monolithPath;
          layout =
            mono.core.management.system-manager.layout or
            mono.layout or
            null;
        in
          if layout == "monolith" || layout == "split" then layout
          else "monolith" # prefer monolith when both exist
      else defaultLayout;

  # Read layout from already-loaded systemConfig attrset
  layoutFromConfig = cfg:
    cfg.core.management.system-manager.layout or
    cfg.layout or
    null;

in
{
  inherit absolute monolithFileName splitDirName;
  inherit pathToList listToSlash listToDots splitConfigFile;
  inherit hasSplitConfigs detectLayoutFromPaths layoutFromConfig;

  # Build config file path for split layout from dotted category (e.g. core.base.hardware)
  buildSplitConfigFile = category:
    let parts = pathToList category;
    in "${absolute.split}/${listToSlash parts}/config.nix";
}
