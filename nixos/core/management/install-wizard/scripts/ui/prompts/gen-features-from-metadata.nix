# Build installer feature catalog from packages metadata (SSOT).
# `meta` is passed by setup-options.nix (no cross-module relative import here).
{ lib, meta }:

let
  modules = meta.modules;

  # Skip deprecated aliases (e.g. game-dev → game-engines)
  activeNames = lib.filter (n: !(modules.${n} ? deprecatedAliasOf)) (lib.attrNames modules);

  groupDisplay = {
    desktop-environment = "Desktop Environment";
    development = "Development";
    gaming = "Gaming & Media";
    virtualization = "Virtualization";
    server = "Services";
  };

  # UI split: container engines vs VMs (metadata group is shared "virtualization")
  uiGroupOf = name: m:
    if lib.elem name [ "docker" "docker-rootless" "podman" ] then "Containerization"
    else groupDisplay.${m.group or "other"} or (m.group or "Other");

  sortedNames = lib.sort (a: b: a < b) activeNames;

  allFeaturesBash =
    "ALL_FEATURES=(\n"
    + lib.concatMapStrings (n: "    \"${n}\"\n") sortedNames
    + ")\n";

  # name → ui group label
  byUiGroup = lib.foldl' (
    acc: name:
    let
      label = uiGroupOf name modules.${name};
    in
    acc
    // {
      ${label} = (acc.${label} or [ ]) ++ [ name ];
    }
  ) { } sortedNames;

  # Stable group order for UI
  groupOrder = [
    "Desktop Environment"
    "Development"
    "Gaming & Media"
    "Containerization"
    "Services"
    "Virtualization"
  ];

  orderedGroups =
    (lib.filter (g: byUiGroup ? ${g}) groupOrder)
    ++ lib.filter (g: !(lib.elem g groupOrder)) (lib.attrNames byUiGroup);

  featureGroupsBash =
    "FEATURE_GROUPS=(\n"
    + lib.concatMapStrings (
      g:
      let
        members = lib.sort (a: b: a < b) byUiGroup.${g};
      in
      "    \"${g}:${lib.concatStringsSep "|" members}\"\n"
    ) orderedGroups
    + ")\n";

  # Exclusive: desktop-environment group + container engines
  deMembers = lib.filter (n: (modules.${n}.group or "") == "desktop-environment") sortedNames;
  containerMembers = lib.filter (n: lib.elem n [ "docker" "docker-rootless" "podman" ]) sortedNames;

  exclusiveBash =
    "declare -A -g EXCLUSIVE_GROUPS=(\n"
    + (
      if deMembers != [ ] then
        "    [\"desktop-environment\"]=\"${lib.concatStringsSep "|" deMembers}\"\n"
      else
        ""
    )
    + (
      if containerMembers != [ ] then
        "    [\"containerization\"]=\"${lib.concatStringsSep "|" containerMembers}\"\n"
      else
        ""
    )
    + ")\n";

  depsBash =
    "declare -A -g FEATURE_DEPENDENCIES=(\n"
    + lib.concatMapStrings (
      n:
      let
        deps = modules.${n}.dependencies or [ ];
      in
      if deps == [ ] then "" else "    [\"${n}\"]=\"${lib.concatStringsSep "|" deps}\"\n"
    ) sortedNames
    + ")\n";

  conflictsBash =
    "declare -A -g FEATURE_CONFLICTS=(\n"
    + lib.concatMapStrings (
      n:
      let
        c = modules.${n}.conflicts or [ ];
      in
      if c == [ ] then "" else "    [\"${n}\"]=\"${lib.concatStringsSep "|" c}\"\n"
    ) sortedNames
    + ")\n";

  systemTypesBash =
    "declare -A -g FEATURE_SYSTEM_TYPES=(\n"
    + lib.concatMapStrings (
      n:
      let
        st = modules.${n}.systemTypes or [ ];
      in
      "    [\"${n}\"]=\"${lib.concatStringsSep "|" st}\"\n"
    ) sortedNames
    + ")\n";

in
''
# ---- Generated from nixos/core/base/packages/lib/metadata.nix (do not edit) ----
${allFeaturesBash}
${featureGroupsBash}
${exclusiveBash}
${depsBash}
${conflictsBash}
${systemTypesBash}
# Pre-baked systemTypes — load_feature_system_types becomes a no-op when already filled.
load_feature_system_types() {
    # FEATURE_SYSTEM_TYPES already set from metadata at package build time.
    return 0
}
# ---- end generated feature catalog ----
''
