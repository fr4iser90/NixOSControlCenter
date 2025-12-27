# TUI Engine API - Bubble Tea templates and builders
{ lib, config }:

let
  # Bubble Tea templates - return script from config like SSH manager
  templates = {
    "5panel" = {
      createTUI = config: title: menuItems: getList: getFilter: getDetails: getActions:
        # Return the script from config like SSH manager does
        config.core.management.tui-engine.moduleManagerTuiScript;
    };
  };

  builders = {
    # Builders will be available through config at runtime
  };

in {
  # Export Bubble Tea API (like cli-registry - functions take config when needed)
  inherit templates builders;
}