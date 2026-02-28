{ config, lib, pkgs, buildGoApplication, gomod2nix, ... }:

let
  # Build tui-engine binary once
  tuiEngineBinary = buildGoApplication {
    pname = "tui-engine";
    version = "1.0.0";
    src = ./.;
    go = pkgs.go;
    modules = ./gomod2nix.toml;
  };

  # Generic TUI runner: uses tui-engine binary + 4 panel scripts + title
  createTuiScript = { name, title, getList, getFilter, getDetails, getActions, footer ? null, actionCmd ? null, getStats ? null, layout ? null, staticMenu ? false }:
    pkgs.writeScriptBin "ncc-${name}-tui" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      export NCC_TUI_TITLE="${title}"
      ${lib.optionalString (footer != null) ''
        export NCC_TUI_FOOTER="${footer}"
      ''}
      ${lib.optionalString (actionCmd != null) ''
        export NCC_TUI_ACTION_CMD="${actionCmd}"
      ''}
      export NCC_TUI_LIST_CMD="${getList}"
      export NCC_TUI_DETAILS_CMD="${getDetails}"
      ${lib.optionalString (layout != null) ''
        export NCC_TUI_LAYOUT="${layout}"
      ''}
      ${lib.optionalString staticMenu ''
        export NCC_TUI_STATIC_MENU="1"
      ''}

      exec ${tuiEngineBinary}/bin/tui-engine \
        "${getList}" \
        "${getFilter}" \
        "${getDetails}" \
        "${getActions}" \
        "${if getStats != null then getStats else ""}"
    '';

  # API wie cli-registry - kein cfg Build-Time dependency
  apiValue = import ./api.nix { inherit lib config; } // {
    createTuiScript = createTuiScript;
    tuiBinary = tuiEngineBinary;
    domainTui = import ./lib/domain-tui.nix { inherit config lib pkgs; };
  };
in {
  # Import the legacy module-manager TUI script (still supported)
  imports = [ ./scripts/module-manager-tui.nix ];

  # Config setzen (hardcoded path wie cli-registry)
  config.core.management.tui-engine = {
    api = apiValue;
    buildGoApplication = buildGoApplication;
    gomod2nix = gomod2nix;
    writeScriptBin = pkgs.writeScriptBin;
    installShellFiles = pkgs.installShellFiles;
    tuiBinary = tuiEngineBinary;
    createTuiScript = createTuiScript;
    domainTui = apiValue.domainTui;
  };
}
