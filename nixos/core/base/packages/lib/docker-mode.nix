# Smart Docker mode selection (SSOT for packages/default.nix + tests)
#
# wants Docker via packageModules "docker" / "docker-rootless" or docker.enable
# Mode:
#   - docker.root = true/false  → forced
#   - else if Swarm or AI-Workspace active → root
#   - else if only docker-rootless requested → rootless
#   - else → rootless (safer default for "docker")
#
# { systemConfig, packageModules, dockerRoot, dockerEnable } → null | "root" | "rootless"

{ systemConfig ? { }
, packageModules ? [ ]
, dockerRoot ? null
, dockerEnable ? false
}:

let
  inherit (builtins) elem;

  # Nested attr lookup without nixpkgs lib
  getPath = path: set:
    builtins.foldl' (acc: key:
      if acc == null then null
      else if builtins.isAttrs acc && builtins.hasAttr key acc then acc.${key}
      else null
    ) set path;

  hasDocker = elem "docker" packageModules;
  hasDockerRootless = elem "docker-rootless" packageModules;
  wantsDocker = hasDocker || hasDockerRootless || dockerEnable;

  hl = getPath [ "modules" "infrastructure" "homelab-manager" ] systemConfig;
  hlAttrs = if hl == null then { } else hl;
  hlNested = if builtins.isAttrs (hlAttrs.homelab or null) then hlAttrs.homelab else { };
  legacyHomelab = let h = getPath [ "homelab" ] systemConfig; in if h == null then { } else h;

  isSwarm =
    (hlAttrs.swarm or null) != null
    || (hlNested.type or null) == "swarm"
    || ((hlNested.role or null) != null && (hlNested.type or "swarm") == "swarm")
    || (getPath [ "swarm" "role" ] legacyHomelab) != null
    || (legacyHomelab.type or null) == "swarm";

  ai = getPath [ "modules" "specialized" "ai-workspace" ] systemConfig;
  aiAttrs = if ai == null then { } else ai;
  features = getPath [ "features" ] systemConfig;
  featuresAttrs = if features == null then { } else features;
  isAiWorkspace =
    (aiAttrs.enable or false)
    || (featuresAttrs.ai-workspace or false);

  needsRoot = isSwarm || isAiWorkspace;

  mode =
    if !wantsDocker then null
    else if dockerRoot == true then "root"
    else if dockerRoot == false then "rootless"
    else if needsRoot then "root"
    else "rootless";
in
  mode
