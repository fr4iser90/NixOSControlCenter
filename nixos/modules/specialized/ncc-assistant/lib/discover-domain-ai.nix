# Build-time discovery of <module>/ai/ packs → tools, docs, skills, domains, context.
# Module owns the pack; ncc-assistant only aggregates. Delete module ⇒ pack gone.
{ lib, pkgs, getModuleMetadata }:

let
  mm = getModuleMetadata "module-manager";
  discovery = import "${mm.path}/lib/discovery.nix" { inherit lib; };
  modules = discovery.discoverAllModules;

  readJsonDir = dir: suffix:
    let
      entries =
        if builtins.pathExists dir
        then builtins.readDir dir
        else { };
    in
    lib.filter (x: x != null) (
      lib.mapAttrsToList (
        name: type:
        if type == "regular" && lib.hasSuffix suffix name then {
          file = name;
          path = "${dir}/${name}";
          id = lib.removeSuffix suffix name;
        } else null
      ) entries
    );

  readTools = aiDir:
    let
      toolsPath = "${aiDir}/tools";
      entries =
        if builtins.pathExists toolsPath
        then builtins.readDir toolsPath
        else { };
    in
    lib.filter (t: t != null) (
      lib.mapAttrsToList (
        name: type:
        if type == "regular" && lib.hasSuffix ".json" name then
          let
            raw = builtins.fromJSON (builtins.readFile "${toolsPath}/${name}");
          in
          raw // { _sourceFile = name; }
        else
          null
      ) entries
    );

  readDocs = aiDir: readJsonDir "${aiDir}/docs" ".md";
  # readJsonDir for .md uses suffix .md but reads as path refs — OK (no fromJSON)
  readDocs' = aiDir:
    let
      docsPath = "${aiDir}/docs";
      entries =
        if builtins.pathExists docsPath
        then builtins.readDir docsPath
        else { };
    in
    lib.filter (d: d != null) (
      lib.mapAttrsToList (
        name: type:
        if type == "regular" && lib.hasSuffix ".md" name then {
          file = name;
          path = "${docsPath}/${name}";
          id = lib.removeSuffix ".md" name;
        } else null
      ) entries
    );

  readSkills = aiDir: readJsonDir "${aiDir}/skills" ".json";
  readDomains = aiDir: readJsonDir "${aiDir}/domains" ".json";
  readContext = aiDir: readJsonDir "${aiDir}/context" ".json";

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
        docs = readDocs' aiDir;
        skills = readSkills aiDir;
        domains = readDomains aiDir;
        context = readContext aiDir;
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
        name =
          if lib.hasPrefix "domain." (t.name or "") then
            t.name
          else
            "domain.${p.domain}.${t.name or "tool"}";
      }
    ) p.tools
  ) packs;

  # Unique output names: skills/<module>--<id>.json
  skillFiles = lib.concatMap (
    p:
    map (s: {
      module = p.module;
      id = "${p.module}--${s.id}";
      outName = "${p.module}--${s.file}";
      inherit (s) path file;
    }) p.skills
  ) packs;

  domainFiles = lib.concatMap (
    p:
    map (d: {
      module = p.module;
      id = "${p.module}--${d.id}";
      outName = "${p.module}--${d.file}";
      inherit (d) path file;
    }) p.domains
  ) packs;

  contextFiles = lib.concatMap (
    p:
    map (c: {
      module = p.module;
      id = "${p.module}--${c.id}";
      outName = "${p.module}--${c.file}";
      inherit (c) path file;
    }) p.context
  ) packs;

  knowledgeIndex = {
    _schema = "ncc-knowledge/1.0";
    _version = "2.0.0";
    _source = "discovered from <module>/ai/ packs";
    tokenBudget = {
      strategy = "load-skill-on-demand";
    };
    skills = map (s: {
      id = s.id;
      file = "skills/${s.outName}";
      module = s.module;
      loaded = false;
    }) skillFiles;
    contexts = map (c: {
      id = c.id;
      file = "context/${c.outName}";
      module = c.module;
      loaded = false;
    }) contextFiles;
    domains =
      (map (d: {
        id = d.id;
        file = "domains/${d.outName}";
        module = d.module;
        loaded = false;
      }) domainFiles)
      ++ (lib.concatMap (
        p:
        map (doc: {
          id = "ai-${p.domain}-${doc.id}";
          file = "domains/ai-${p.domain}-${doc.id}.md";
          module = p.module;
          loaded = false;
        }) p.docs
      ) packs);
    modules = [ ];
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

  knowledgeRoot = pkgs.runCommand "ncc-discovered-knowledge" { } ''
    mkdir -p $out/skills $out/domains $out/context
    ${lib.concatMapStrings (s: ''
      cp ${lib.escapeShellArg s.path} $out/skills/${s.outName}
    '') skillFiles}
    ${lib.concatMapStrings (d: ''
      cp ${lib.escapeShellArg d.path} $out/domains/${d.outName}
    '') domainFiles}
    ${lib.concatMapStrings (c: ''
      cp ${lib.escapeShellArg c.path} $out/context/${c.outName}
    '') contextFiles}
    # markdown domain docs from packs
    ${lib.concatMapStrings (
      p:
      lib.concatMapStrings (d: ''
        cp ${lib.escapeShellArg d.path} $out/domains/ai-${p.domain}-${
          lib.removeSuffix ".md" d.file
        }.md
      '') p.docs
    ) packs}
    cp ${pkgs.writeText "knowledge-index.json" (builtins.toJSON knowledgeIndex)} $out/index.json
    touch $out/skills/.keep $out/domains/.keep $out/context/.keep
  '';

  index = {
    version = 2;
    packs = map (p: {
      inherit (p) module domain description;
      toolCount = builtins.length p.tools;
      skillCount = builtins.length p.skills;
      tools = map (t: t.name or "?") p.tools;
    }) packs;
    tools = flatTools;
  };

  indexFile = pkgs.writeText "ncc-domain-ai-tools.json" (builtins.toJSON index);
in
{
  inherit packs flatTools index indexFile docsRoot knowledgeRoot knowledgeIndex;
}
