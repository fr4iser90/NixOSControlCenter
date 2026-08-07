# CLI Registry API — behavior only. Prefer: getModuleApi "cli-registry"
# Raw import (config.nix) must pass metadata + getModuleMetadata explicitly.
{ lib, metadata, getModuleMetadata }:

let
  selfPath = metadata.configPath;
  fromConfig = config: config.${selfPath};
in
rec {
  inherit fromConfig;

  # Dotted option key (options.${configPath}), not nested core.management.…
  registerCommandsFor = moduleName: commands:
    lib.setAttrByPath [ selfPath "commandSets" moduleName ] commands;

  registerGuiDomain = id: attrs:
    lib.setAttrByPath [ selfPath "guiDomains" id ] {
      label = attrs.label or id;
      description = attrs.description or "";
      enabled = attrs.enabled or false;
    };

  # Rich Qt page lives in the module (`ui/gui/page.py`). Engine only aggregates.
  # `pageDir` must contain page.py exporting create_page() and/or Page.
  registerGuiPage = id: pageDir:
    lib.setAttrByPath [ selfPath "guiPages" id ] {
      path = pageDir;
    };

  getRegisteredCommands = config:
    let
      commandSets = (fromConfig config).commandSets or {};
    in
      builtins.concatLists (builtins.attrValues commandSets);

  getCommandsByDomain = config: domain:
    lib.filter (cmd: cmd.domain or null == domain) (getRegisteredCommands config);

  getDomains = config:
    let
      domains = lib.unique (map (cmd: cmd.domain or "unknown") (getRegisteredCommands config));
    in
      lib.sort (a: b: a < b) (lib.filter (d: d != "unknown") domains);

  getSubcommands = config: parentName:
    lib.filter (cmd: cmd.parent or null == parentName) (getRegisteredCommands config);

  getTopLevelCommands = config: domain:
    lib.filter (cmd: cmd.parent or null == null) (getCommandsByDomain config domain);

  getPublicCommands = config:
    lib.filter (cmd: !(cmd.internal or false)) (getRegisteredCommands config);

  guiDomains = config: (fromConfig config).guiDomains or {};

  guiPages = config: (fromConfig config).guiPages or {};
}
