# Build-time discovery of <module>/ai/ packs → JSON index + docs store path
{ lib, pkgs, getModuleMetadata }:

let
  mm = getModuleMetadata "module-manager";
  discovery = import "${mm.path}/lib/discovery.nix" { inherit lib; };
  modules = discovery.discoverAllModules;

  readTools = aiDir:
    let
      toolsPath = "${aiDir}/tools";
      entries =
        if builtins.pathExists toolsPath
        then builtins.readDir toolsPath
        else {};
    in
      lib.filter (t: t != null) (
        lib.mapAttrsToList (
          name: type:
            if type == "regular" && lib.hasSuffix ".json" name then
              let
                raw = builtins.fromJSON (builtins.readFile "${toolsPath}/${name}");
              in
                raw // {
                  _sourceFile = name;
                }
            else
              null
        ) entries
      );

  readDocs = aiDir:
    let
      docsPath = "${aiDir}/docs";
      entries =
        if builtins.pathExists docsPath
        then builtins.readDir docsPath
        else {};
    in
      lib.filter (d: d != null) (
        lib.mapAttrsToList (
          name: type:
            if type == "regular" && lib.hasSuffix ".md" name then {
              file = name;
              path = "${docsPath}/${name}";
            } else null
        ) entries
      );

  loadPack = m:
    let
      aiDir = "${m.path}/ai";
      manPath = "${aiDir}/manifest.nix";
    in
      if !(builtins.pathExists manPath) then
        null
      else
        let
          manifest = import manPath;
          enabled = manifest.enable or true;
        in
          if !enabled then
            null
          else {
            module = m.name;
            domain = manifest.domain or m.name;
            description = manifest.description or "";
            path = m.path;
            tools = readTools aiDir;
            docs = readDocs aiDir;
          };

  packs = lib.filter (p: p != null) (map loadPack modules);

  flatTools = lib.concatMap (
    p:
      map (
        t:
          t
          // {
            domain = p.domain;
            module = p.module;
            # Stable namespaced name if author omitted prefix
            name =
              if lib.hasPrefix "domain." (t.name or "") then
                t.name
              else
                "domain.${p.domain}.${t.name or "tool"}";
          }
      ) p.tools
  ) packs;

  index = {
    version = 1;
    packs = map (p: {
      inherit (p) module domain description;
      toolCount = builtins.length p.tools;
      tools = map (t: t.name or "?") p.tools;
    }) packs;
    tools = flatTools;
  };

  docsRoot = pkgs.runCommand "ncc-domain-ai-docs" { } ''
    mkdir -p $out/domains
    ${lib.concatMapStrings (
      p:
        lib.concatMapStrings (d: ''
          cp ${lib.escapeShellArg d.path} $out/domains/ai-${p.domain}-${
            lib.removeSuffix ".md" d.file
          }.md
        '') p.docs
    ) packs}
    touch $out/domains/.keep
  '';

  indexFile = pkgs.writeText "ncc-domain-ai-tools.json" (builtins.toJSON index);
in
{
  inherit packs flatTools index indexFile docsRoot;
}
