# Pure-Nix layout convert helpers (no JSON config artifacts)
# Used by ncc-config-layout via `nix eval --impure --raw`
{ lib }:

rec {
  findConfigs = currentDir: relative:
    let
      dir = builtins.readDir currentDir;
      names = builtins.attrNames dir;
      hasConfig = builtins.elem "config.nix" names && dir."config.nix" == "regular";
      subDirs = builtins.filter (n: dir.${n} == "directory") names;
      self = if hasConfig then [{ path = relative; file = currentDir + "/config.nix"; }] else [];
      kids = lib.concatMap (d:
        findConfigs (currentDir + "/${d}") (if relative == "" then d else relative + "/" + d)
      ) subDirs;
    in self ++ kids;

  # Module data paths must never land in systemConfig (nixify mapping DB etc.)
  isJunkDataPath = v:
    let s = if builtins.isPath v then toString v else if builtins.isString v then v else null;
    in s != null && (
      lib.hasInfix "/systemConfig/" s
      || lib.hasInfix "mapping-database" s
      || (lib.hasSuffix ".json" s && lib.hasPrefix "/" s)
    );

  keepAttr = name: value:
    if value == null then false
    else if name == "databasePath" && (builtins.isPath value || isJunkDataPath value) then false
    else if name == "mapping" && builtins.isAttrs value && value == {} then false
    else true;

  # Drop Nix paths + junk databasePath; recurse; prune empty mapping = {}
  scrub = value:
    if builtins.isPath value then
      null
    else if builtins.isAttrs value then
      let
        mapped = lib.mapAttrs (_: scrub) value;
        filtered = lib.filterAttrs keepAttr mapped;
      in
        lib.filterAttrs keepAttr filtered # prune mapping={} after databasePath drop
    else if builtins.isList value then
      builtins.filter (x: x != null) (map scrub value)
    else if builtins.isString value && isJunkDataPath value then
      null
    else
      value;

  tryLoadLeaf = file:
    let raw = builtins.tryEval (import file);
    in if !raw.success then null
    else
      let cleaned = scrub raw.value;
      in if cleaned == null then {} else cleaned;

  loadSplit = configsDir:
    let
      configs = if builtins.pathExists configsDir then findConfigs configsDir "" else [];
      mergeOne = acc: c:
        let value = tryLoadLeaf c.file;
        in if value == null then acc
        else
          let
            parts = if c.path == "" then [] else lib.splitString "/" c.path;
            nested = if parts == [] then value else lib.setAttrByPath parts value;
          in lib.recursiveUpdate acc nested;
    in scrub (builtins.foldl' mergeOne {} configs);

  failedLeaves = configsDir:
    let
      configs = if builtins.pathExists configsDir then findConfigs configsDir "" else [];
    in map (c: c.path) (builtins.filter (c: !(builtins.tryEval (import c.file)).success) configs);

  stampMonolith = cfg:
    lib.recursiveUpdate cfg {
      core.management.system-manager = (cfg.core.management.system-manager or {}) // {
        configVersion = "2.0";
        layout = "monolith";
      };
    };

  stampSplitLeaf = modulePath: leaf:
    if modulePath == "core/management/system-manager" then
      leaf // { configVersion = "2.0"; layout = "split"; }
    else leaf;

  toNixSource = attrs:
    lib.generators.toPretty { multiline = true; } (scrub attrs) + "\n";

  splitToMonolith =
    { configsDir, monolithPath }:
    let
      fromSplit = loadSplit configsDir;
      fromMono =
        if monolithPath != null && builtins.pathExists monolithPath
        then scrub (import monolithPath)
        else {};
      merged = stampMonolith (lib.recursiveUpdate fromMono fromSplit);
    in toNixSource merged;

  leafFromMonolith =
    { monolithPath, modulePath }:
    let
      mono = scrub (import monolithPath);
      parts = lib.splitString "/" modulePath;
      leaf = lib.attrByPath parts null mono;
    in
      if leaf == null then ""
      else toNixSource (stampSplitLeaf modulePath (scrub leaf));

  userNames =
    { monolithPath }:
    let mono = scrub (import monolithPath);
    in lib.concatStringsSep "\n" (lib.attrNames (mono.users or {}));

  userLeafFromMonolith =
    { monolithPath, username }:
    let
      mono = scrub (import monolithPath);
      leaf = mono.users.${username} or null;
    in if leaf == null then "" else toNixSource (scrub leaf);
}
