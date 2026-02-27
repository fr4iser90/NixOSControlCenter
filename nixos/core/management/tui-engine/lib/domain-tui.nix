{ config, lib, pkgs }:

let
  cliRegistry = config.core.management.cli-registry.api;
  tuiEngine = config.core.management.tui-engine.api;

  toItem = cmd: {
    name = cmd.name;
    description = cmd.description or cmd.shortHelp or "";
    status = if (cmd.parent or null) != null then "subcommand" else "command";
    category = cmd.category or cmd.domain or "general";
    path = cmd.parent or cmd.domain or cmd.name;
  };

  buildListScript = { name, items }:
    pkgs.writeScript "ncc-${name}-tui-list" ''
      #!${pkgs.bash}/bin/bash
      cat << 'EOF'
      ${builtins.toJSON items}
      EOF
    '';

  buildTextScript = { name, content }:
    pkgs.writeScript "ncc-${name}-tui-text" ''
      #!${pkgs.bash}/bin/bash
      cat << 'EOF'
      ${content}
      EOF
    '';

  buildDomainTui = { name, title, domain, footer ? null, extraInfo ? "", statsContent ? null, commands ? [], layout ? null }:
    let
      items = map toItem commands;
      listScript = buildListScript { inherit name items; };
      filterScript = buildTextScript { name = "${name}-filter"; content = "Domain: ${domain}\nCommands: ${toString (builtins.length items)}"; };
      detailsScript = buildTextScript { name = "${name}-details"; content = ''
Use:
  ncc ${domain} <action>

${extraInfo}
''; };
      actionsScript = buildTextScript { name = "${name}-actions"; content = "Enter: run ncc ${domain} {name}"; };
      statsScript = buildTextScript { name = "${name}-stats"; content = if statsContent != null then statsContent else ""; };
    in
      tuiEngine.createTuiScript {
        name = name;
        title = title;
        getList = listScript;
        getFilter = filterScript;
        getDetails = detailsScript;
        getActions = actionsScript;
        getStats = statsScript;
        footer = footer;
        actionCmd = "ncc ${domain} {name}";
        layout = layout;
      };

  buildRootTui = { name, title, footer ? null, layout ? null }:
    let
      domains = cliRegistry.getDomains config;
      items = map (domain: {
        name = domain;
        description = "Manage ${domain} domain";
        status = "domain";
        category = domain;
        path = domain;
      }) domains;
      listScript = buildListScript { inherit name items; };
      filterScript = buildTextScript { name = "${name}-filter"; content = "Domains: ${toString (builtins.length items)}"; };
      detailsScript = buildTextScript { name = "${name}-details"; content = ''
Use:
  ncc <domain>

Select a domain in the menu to see available commands.
''; };
      actionsScript = buildTextScript { name = "${name}-actions"; content = "Enter: open ncc {name}"; };
    in
      tuiEngine.createTuiScript {
        name = name;
        title = title;
        getList = listScript;
        getFilter = filterScript;
        getDetails = detailsScript;
        getActions = actionsScript;
        footer = footer;
        actionCmd = "ncc {name}";
        layout = layout;
      };
in {
  inherit buildDomainTui buildRootTui;
}