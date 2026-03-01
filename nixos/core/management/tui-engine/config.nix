{ config, lib, pkgs, buildGoApplication, gomod2nix, ... }:

let
  # Import module discovery to find all modules with TUI files
  discoveryLib = import ../module-manager/lib/discovery.nix { inherit lib; };
  allModules = discoveryLib.discoverAllModules;
  
  # TUI Engine is a BUILDER/API provider - modules keep their own TUI files!
  # Modules build their own binaries using TUI Engine APIs
  
  # Generate go.mod content (no replace directives needed - files are merged)
  # Module name must match the directory structure
  goModContent = ''
    module core/management/tui-engine

    go 1.25.0

    require (
    	github.com/charmbracelet/bubbles v0.21.0
    	github.com/charmbracelet/bubbletea v1.3.10
    	github.com/charmbracelet/glamour v0.10.0
    	github.com/charmbracelet/lipgloss v1.1.1-0.20250404203927-76690c660834
    	github.com/charmbracelet/x/exp/teatest v0.0.0-20251023181713-f594ac034d6b
    	github.com/muesli/go-app-paths v0.2.2
    	github.com/spf13/cobra v1.10.1
    	github.com/stretchr/testify v1.11.1
    	modernc.org/sqlite v1.39.1
    )

    require (
    	github.com/alecthomas/chroma/v2 v2.20.0 // indirect
    	github.com/atotto/clipboard v0.1.4 // indirect
    	github.com/aymanbagabas/go-osc52/v2 v2.0.1 // indirect
    	github.com/aymanbagabas/go-udiff v0.3.1 // indirect
    	github.com/aymerick/douceur v0.2.0 // indirect
    	github.com/charmbracelet/colorprofile v0.3.2 // indirect
    	github.com/charmbracelet/x/ansi v0.10.2 // indirect
    	github.com/charmbracelet/x/cellbuf v0.0.13 // indirect
    	github.com/charmbracelet/x/exp/golden v0.0.0-20251023181713-f594ac034d6b // indirect
    	github.com/charmbracelet/x/exp/slice v0.0.0-20251023181713-f594ac034d6b // indirect
    	github.com/charmbracelet/x/term v0.2.1 // indirect
    	github.com/clipperhouse/uax29/v2 v2.2.0 // indirect
    	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc // indirect
    	github.com/dlclark/regexp2 v1.11.5 // indirect
    	github.com/dustin/go-humanize v1.0.1 // indirect
    	github.com/erikgeiser/coninput v0.0.0-20211004153227-1c3628e74d0f // indirect
    	github.com/google/uuid v1.6.0 // indirect
    	github.com/gorilla/css v1.0.1 // indirect
    	github.com/inconshreveable/mousetrap v1.1.0 // indirect
    	github.com/kr/pretty v0.3.1 // indirect
    	github.com/lucasb-eyer/go-colorful v1.3.0 // indirect
    	github.com/mattn/go-isatty v0.0.20 // indirect
    	github.com/mattn/go-localereader v0.0.1 // indirect
    	github.com/mattn/go-runewidth v0.0.19 // indirect
    	github.com/microcosm-cc/bluemonday v1.0.27 // indirect
    	github.com/mitchellh/go-homedir v1.1.0 // indirect
    	github.com/muesli/ansi v0.0.0-20230316100256-276c6243b2f6 // indirect
    	github.com/muesli/cancelreader v0.2.2 // indirect
    	github.com/muesli/reflow v0.3.0 // indirect
    	github.com/muesli/termenv v0.16.0 // indirect
    	github.com/ncruces/go-strftime v1.0.0 // indirect
    	github.com/pmezard/go-difflib v1.0.1-0.20181226105442-5d4384ee4fb2 // indirect
    	github.com/remyoudompheng/bigfft v0.0.0-20230129092748-24d4a6f8daec // indirect
    	github.com/rivo/uniseg v0.4.7 // indirect
    	github.com/rogpeppe/go-internal v1.11.0 // indirect
    	github.com/sahilm/fuzzy v0.1.1 // indirect
    	github.com/spf13/pflag v1.0.10 // indirect
    	github.com/stretchr/objx v0.5.3 // indirect
    	github.com/xo/terminfo v0.0.0-20220910002029-abceb7e1c41e // indirect
    	github.com/yuin/goldmark v1.7.13 // indirect
    	github.com/yuin/goldmark-emoji v1.0.6 // indirect
    	golang.org/x/exp v0.0.0-20251023183803-a4bb9ffd2546 // indirect
    	golang.org/x/net v0.46.0 // indirect
    	golang.org/x/sys v0.37.0 // indirect
    	golang.org/x/term v0.36.0 // indirect
    	golang.org/x/text v0.30.0 // indirect
    	gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c // indirect
    	gopkg.in/yaml.v3 v3.0.1 // indirect
    	modernc.org/libc v1.66.10 // indirect
    	modernc.org/mathutil v1.7.1 // indirect
    	modernc.org/memory v1.11.0 // indirect
    )
  '';
  
  # Generate go.mod file
  generatedGoMod = pkgs.writeText "go.mod" goModContent;
  
  # TUI Engine source - ONLY TUI Engine's own files, NO module files!
  # TUI Engine is a builder/API provider - modules build their own binaries
  tuiEngineSrc = pkgs.stdenv.mkDerivation {
    name = "tui-engine-src";
    buildInputs = [ pkgs.coreutils ];
    
    unpackPhase = ''
      true
    '';
    
    buildPhase = ''
      # Create output directory (this will be the tui-engine directory)
      mkdir -p $out
      # Copy ONLY tui-engine's own files
      cp -r ${../../..}/core/management/tui-engine/* $out/ || true
      # Set write permissions
      chmod -R u+w $out || true
      # Place generated go.mod in tui-engine directory
      install -m 644 ${generatedGoMod} $out/go.mod
    '';
    
    installPhase = ''
      true
    '';
  };

  # Function to build a TUI binary for a specific module
  # Each module builds its own binary with its own TUI files
  createTuiBinary = { modulePath, moduleName }:
    let
      # Create source directory for this module's TUI
      moduleTuiSrc = pkgs.stdenv.mkDerivation {
        name = "${moduleName}-tui-src";
        buildInputs = [ pkgs.coreutils ];
        
        unpackPhase = ''
          true
        '';
        
        buildPhase = ''
          # Create output directory structure
          mkdir -p $out
          
          # Copy TUI Engine files (main.go, go.mod, etc.)
          # Exclude src/tui if it exists (we'll copy module files there)
          cp -r ${tuiEngineSrc}/* $out/ || true
          chmod -R u+w $out || true
          
          # Remove empty src/tui if it exists (from tuiEngineSrc)
          rm -rf $out/src/tui || true
          
          # Copy module's own TUI files into src/tui/
          # Module TUI files stay in their own directory structure
          # CRITICAL: This must happen AFTER copying tuiEngineSrc and removing empty src/tui
          # NO FALLBACKS - Module MUST have its own TUI Go files
          mkdir -p $out/src/tui
          if [ -d "${modulePath}/ui/tui" ] && [ -n "$(ls -A ${modulePath}/ui/tui/*.go 2>/dev/null)" ]; then
            # Module has its own TUI Go files - use them
            cp -r ${modulePath}/ui/tui/*.go $out/src/tui/ || true
          else
            # Module has no TUI Go files - FAIL
            # NO FALLBACKS - every module MUST have its own TUI files
            echo "ERROR: Module ${moduleName} has no TUI Go files at ${modulePath}/ui/tui/" >&2
            echo "ERROR: Every module that uses createTuiScript MUST have its own TUI Go files!" >&2
            echo "ERROR: No fallbacks, no shared bases - each module is isolated!" >&2
            exit 1
          fi
        '';
        
        installPhase = ''
          true
        '';
      };
    in
      buildGoApplication {
        pname = "${moduleName}-tui";
        version = "1.0.0";
        src = moduleTuiSrc;
        go = pkgs.go;
        modules = ./gomod2nix.toml;
      };

  # Generic TUI runner: builds module-specific binary + 4 panel scripts + title
  # Each module gets its own isolated TUI binary with its own TUI files
  # modulePath is REQUIRED - no fallbacks, every module MUST have its own TUI files
  createTuiScript = { name, title, getList, getFilter, getDetails, getActions, footer ? null, actionCmd ? null, getStats ? null, layout ? null, staticMenu ? false, modulePath }:
    let
      # Build module-specific binary - modulePath is REQUIRED
      # Every module MUST have its own TUI files - no exceptions, no fallbacks
      moduleBinary = createTuiBinary {
        modulePath = modulePath;
        moduleName = name;
      };
      
      # buildGoApplication creates binary named "tui-engine" (from package name in go.mod)
      # NOT "${name}-tui" - the binary name comes from the Go package, not pname
      binaryName = "tui-engine";
    in
      pkgs.writeScriptBin "ncc-${name}-tui" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        # Parse --debug flag
        DEBUG_MODE=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --debug|-d)
              DEBUG_MODE="1"
              shift
              ;;
            *)
              # Unknown arguments are ignored (tui-engine doesn't accept user args)
              shift
              ;;
          esac
        done

        # Set debug environment variable if --debug was passed
        if [[ -n "$DEBUG_MODE" ]]; then
          export NCC_TUI_DEBUG="1"
        fi

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

        exec ${moduleBinary}/bin/${binaryName} \
          "${getList}" \
          "${getFilter}" \
          "${getDetails}" \
          "${getActions}" \
          "${if getStats != null then getStats else ""}"
      '';

  # API wie cli-registry - kein cfg Build-Time dependency
  apiValue = import ./api.nix { inherit lib config; } // {
    createTuiScript = createTuiScript;
    createTuiBinary = createTuiBinary;
    tuiEngineSrc = tuiEngineSrc;  # Expose src for modules to build their own binaries
    domainTui = import ./lib/domain-tui.nix { inherit config lib pkgs; };
  };
in {
  # Config setzen (hardcoded path wie cli-registry)
  config.core.management.tui-engine = {
    api = apiValue;
    buildGoApplication = buildGoApplication;
    gomod2nix = gomod2nix;
    writeScriptBin = pkgs.writeScriptBin;
    installShellFiles = pkgs.installShellFiles;
    tuiEngineSrc = tuiEngineSrc;  # Expose src for modules to build their own binaries
    createTuiScript = createTuiScript;
    createTuiBinary = createTuiBinary;
    domainTui = apiValue.domainTui;
  };
}
