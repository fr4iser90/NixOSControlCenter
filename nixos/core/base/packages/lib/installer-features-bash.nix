# Packages-owned installer feature catalog → bash (SSOT for install-wizard).
# Consumers (install-wizard) must obtain this via getModuleApi "packages", not by
# re-implementing group/module wiring or importing metadata across layers.
{ lib, metadata ? import ./metadata.nix }:

let
  modules = metadata.modules;

  activeNames = lib.filter (
    n: !(modules.${n} ? deprecatedAliasOf) && !(modules.${n}.wizardHide or false)
  ) (lib.attrNames modules);

  # Taxonomy labels live with packages (not in install-wizard).
  groupDisplay = {
    desktop-environment = "Desktop Environment";
    development = "Development";
    gaming = "Gaming & Media";
    virtualization = "Virtualization";
    server = "Services";
  };

  uiGroupOf =
    name: m:
    if m ? uiGroup then
      m.uiGroup
    else
      groupDisplay.${m.group or "other"} or (m.group or "Other");

  exclusiveKeyOf =
    m:
    if m ? exclusiveGroup then
      m.exclusiveGroup
    else if (m.group or "") == "desktop-environment" then
      "desktop-environment"
    else
      null;

  sortedNames = lib.sort (a: b: a < b) activeNames;

  allFeaturesBash =
    "ALL_FEATURES=(\n"
    + lib.concatMapStrings (n: "    \"${n}\"\n") sortedNames
    + ")\n";

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

  byExclusive = lib.foldl' (
    acc: name:
    let
      key = exclusiveKeyOf modules.${name};
    in
    if key == null then
      acc
    else
      acc
      // {
        ${key} = (acc.${key} or [ ]) ++ [ name ];
      }
  ) { } sortedNames;

  exclusiveBash =
    "declare -A -g EXCLUSIVE_GROUPS=(\n"
    + lib.concatMapStrings (
      key:
      let
        members = lib.sort (a: b: a < b) byExclusive.${key};
      in
      "    [\"${key}\"]=\"${lib.concatStringsSep "|" members}\"\n"
    ) (lib.sort (a: b: a < b) (lib.attrNames byExclusive))
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
# ---- packages installer feature catalog (getModuleApi "packages") — do not edit ----
${allFeaturesBash}
${featureGroupsBash}
${exclusiveBash}
${depsBash}
${conflictsBash}
${systemTypesBash}
# Pre-baked systemTypes — load_feature_system_types is a no-op when already filled.
load_feature_system_types() {
    return 0
}
# ---- end packages feature catalog ----
''
