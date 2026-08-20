# Build-time MODULE_INVENTORY.md for AI_KNOWLEDGE append only.
# Runtime list_modules / health use live `ncc modules list --json` — no JSON export.
{ lib, pkgs, getModuleMetadata }:

let
  mm = getModuleMetadata "module-manager";
  discovery = import "${mm.path}/lib/discovery.nix" { inherit lib; };
  modules = discovery.discoverAllModules;

  # category is dotted (modules.infrastructure.stack-manager) → repo-relative path
  relPath = m: "nixos/${lib.replaceStrings [ "." ] [ "/" ] m.category}";

  entries = map (m: {
    name = m.name;
    domain = m.domain; # "core" | "modules"
    kind = if m.domain == "core" then "core" else "optional";
    category = m.category;
    configPath = m.configPath;
    path = relPath m;
    description = m.description or m.name;
    defaultEnabled = m.defaultEnabled or (m.domain == "core");
  }) modules;

  inventoryMarkdown =
    let
      core = lib.filter (m: m.kind == "core") entries;
      optional = lib.filter (m: m.kind == "optional") entries;
      line = m: "- `${m.name}` — `${m.path}` (`${m.category}`)\n";
    in
    ''
      # MODULE_INVENTORY (generated at build — do not edit)

      Source: `discoverAllModules` at package build. Runtime truth: `ncc modules list --json`.

      ## core (${toString (builtins.length core)})

      ${lib.concatMapStrings line core}
      ## optional (${toString (builtins.length optional)})

      ${lib.concatMapStrings line optional}
    '';

  inventoryFile = pkgs.writeText "MODULE_INVENTORY.md" inventoryMarkdown;

in
{
  inherit inventoryFile entries;
}
