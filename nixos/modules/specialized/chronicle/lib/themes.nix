# Custom Theme System
# CSS template system for customizing report appearance
# - Predefined theme gallery
# - User-defined themes
# - CSS variable system
# - Theme preview and switching

{ config, lib, pkgs, ... }:

let
  cfg = config.services.nixos-control-center.chronicle;
  
  # Built-in themes
  builtinThemes = {
    default = {
      name = "Default";
      description = "Clean, professional default theme";
      author = "NixOS Step Recorder";
      variables = {
        # Colors
        primary-color = "#3b82f6";
        secondary-color = "#8b5cf6";
        background-color = "#ffffff";
        text-color = "#1f2937";
        border-color = "#e5e7eb";
        
        # Dark mode colors
        dark-background = "#1f2937";
        dark-text = "#f9fafb";
        dark-border = "#374151";
        
        # Spacing
        spacing-xs = "0.25rem";
        spacing-sm = "0.5rem";
        spacing-md = "1rem";
        spacing-lg = "1.5rem";
        spacing-xl = "2rem";
        
        # Typography
        font-family = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";
        font-size-base = "16px";
        font-size-sm = "14px";
        font-size-lg = "18px";
        font-size-xl = "24px";
        
        # Borders
        border-radius = "0.5rem";
        border-width = "1px";
        
        # Shadows
        shadow-sm = "0 1px 2px 0 rgba(0, 0, 0, 0.05)";
        shadow-md = "0 4px 6px -1px rgba(0, 0, 0, 0.1)";
        shadow-lg = "0 10px 15px -3px rgba(0, 0, 0, 0.1)";
      };
    };
    
    professional = {
      name = "Professional";
      description = "Corporate-friendly professional theme";
      author = "NixOS Step Recorder";
      variables = {
        primary-color = "#2563eb";
        secondary-color = "#1e40af";
        background-color = "#f8fafc";
        text-color = "#0f172a";
        border-color = "#cbd5e1";
        
        dark-background = "#0f172a";
        dark-text = "#f1f5f9";
        dark-border = "#334155";
        
        font-family = "'Inter', 'Helvetica Neue', Arial, sans-serif";
        border-radius = "0.25rem";
      };
    };
    
    minimalist = {
      name = "Minimalist";
      description = "Clean, minimal design with lots of whitespace";
      author = "NixOS Step Recorder";
      variables = {
        primary-color = "#000000";
        secondary-color = "#6b7280";
        background-color = "#ffffff";
        text-color = "#111827";
        border-color = "#f3f4f6";
        
        dark-background = "#111827";
        dark-text = "#ffffff";
        dark-border = "#1f2937";
        
        spacing-xs = "0.5rem";
        spacing-sm = "1rem";
        spacing-md = "2rem";
        spacing-lg = "3rem";
        spacing-xl = "4rem";
        
        font-family = "'Georgia', 'Times New Roman', serif";
        border-radius = "0";
        border-width = "2px";
      };
    };
    
    vibrant = {
      name = "Vibrant";
      description = "Colorful, modern theme with bold colors";
      author = "NixOS Step Recorder";
      variables = {
        primary-color = "#ec4899";
        secondary-color = "#8b5cf6";
        background-color = "#fdf2f8";
        text-color = "#831843";
        border-color = "#f9a8d4";
        
        dark-background = "#831843";
        dark-text = "#fce7f3";
        dark-border = "#be185d";
        
        font-family = "'Poppins', 'Montserrat', sans-serif";
        border-radius = "1rem";
        shadow-md = "0 4px 6px -1px rgba(236, 72, 153, 0.3)";
      };
    };
    
    high-contrast = {
      name = "High Contrast";
      description = "Accessibility-focused high contrast theme";
      author = "NixOS Step Recorder";
      variables = {
        primary-color = "#0000ff";
        secondary-color = "#000080";
        background-color = "#ffffff";
        text-color = "#000000";
        border-color = "#000000";
        
        dark-background = "#000000";
        dark-text = "#ffffff";
        dark-border = "#ffffff";
        
        font-size-base = "18px";
        font-size-sm = "16px";
        font-size-lg = "20px";
        font-size-xl = "28px";
        
        border-width = "2px";
      };
    };
  };

in {
  # Theme management script
  themeManagerScript = pkgs.writeShellScriptBin "chronicle-themes" ''
    #!${pkgs.bash}/bin/bash
    # Theme Management System
    # Version: 1.2.0
    
    set -euo pipefail
    
    # Configuration
    THEMES_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/nixos-chronicle/themes"
    CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/nixos-chronicle/themes"
    
    # Create directories
    mkdir -p "$THEMES_DIR" "$CACHE_DIR"
    
    # Initialize builtin themes
    init_builtin_themes() {
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: theme: ''
        cat > "$THEMES_DIR/${name}.json" <<'THEME_EOF'
        ${builtins.toJSON theme}
        THEME_EOF
      '') builtinThemes)}
    }
    
    # List available themes
    list_themes() {
      echo "Available Themes:"
      echo "================="
      echo
      
      for theme_file in "$THEMES_DIR"/*.json; do
        if [[ -f "$theme_file" ]]; then
          local theme_name=$(basename "$theme_file" .json)
          local theme_title=$(${pkgs.jq}/bin/jq -r '.name' "$theme_file")
          local theme_desc=$(${pkgs.jq}/bin/jq -r '.description' "$theme_file")
          local theme_author=$(${pkgs.jq}/bin/jq -r '.author' "$theme_file")
          
          echo "📦 $theme_name"
          echo "   Name: $theme_title"
          echo "   Description: $theme_desc"
          echo "   Author: $theme_author"
          echo
        fi
      done
    }
    
    # Show theme details
    show_theme() {
      local theme_name="$1"
      local theme_file="$THEMES_DIR/$theme_name.json"
      
      if [[ ! -f "$theme_file" ]]; then
        echo "Error: Theme '$theme_name' not found"
        return 1
      fi
      
      echo "Theme: $theme_name"
      echo "===================="
      ${pkgs.jq}/bin/jq '.' "$theme_file"
    }
    
    # Generate CSS from theme
    generate_css() {
      local theme_name="$1"
      local theme_file="$THEMES_DIR/$theme_name.json"
      local output_file="''${2:-$CACHE_DIR/$theme_name.css}"
      
      if [[ ! -f "$theme_file" ]]; then
        echo "Error: Theme '$theme_name' not found"
        return 1
      fi
      
      # Read theme variables
      local variables=$(${pkgs.jq}/bin/jq -r '.variables | to_entries | .[] | "--\(.key): \(.value);"' "$theme_file")
      
      # Generate CSS
      cat > "$output_file" <<CSS_EOF
    /* Theme: $(${pkgs.jq}/bin/jq -r '.name' "$theme_file") */
    /* Description: $(${pkgs.jq}/bin/jq -r '.description' "$theme_file") */
    /* Author: $(${pkgs.jq}/bin/jq -r '.author' "$theme_file") */
    
    :root {
      $variables
    }
    
    /* Apply theme variables */
    body {
      font-family: var(--font-family, sans-serif);
      font-size: var(--font-size-base, 16px);
      color: var(--text-color, #000);
      background-color: var(--background-color, #fff);
    }
    
    .step-container {
      border: var(--border-width, 1px) solid var(--border-color, #ddd);
      border-radius: var(--border-radius, 0.5rem);
      box-shadow: var(--shadow-md, 0 4px 6px rgba(0,0,0,0.1));
      padding: var(--spacing-md, 1rem);
      margin-bottom: var(--spacing-lg, 1.5rem);
    }
    
    .step-header {
      color: var(--primary-color, #3b82f6);
      font-size: var(--font-size-lg, 18px);
      margin-bottom: var(--spacing-sm, 0.5rem);
    }
    
    .step-screenshot {
      border-radius: var(--border-radius, 0.5rem);
      box-shadow: var(--shadow-sm, 0 1px 2px rgba(0,0,0,0.05));
    }
    
    .step-metadata {
      font-size: var(--font-size-sm, 14px);
      color: var(--secondary-color, #6b7280);
    }
    
    /* Dark mode support */
    @media (prefers-color-scheme: dark) {
      body {
        color: var(--dark-text, #fff);
        background-color: var(--dark-background, #1f2937);
      }
      
      .step-container {
        border-color: var(--dark-border, #374151);
      }
    }
    CSS_EOF
      
      echo "CSS generated: $output_file"
    }
    
    # Create new theme
    create_theme() {
      local theme_name="$1"
      local theme_file="$THEMES_DIR/$theme_name.json"
      
      if [[ -f "$theme_file" ]]; then
        echo "Error: Theme '$theme_name' already exists"
        return 1
      fi
      
      # Interactive theme creation
      echo "Creating new theme: $theme_name"
      echo "=========================="
      echo
      
      read -p "Theme display name: " display_name
      read -p "Description: " description
      read -p "Author: " author
      
      cat > "$theme_file" <<THEME_EOF
    {
      "name": "$display_name",
      "description": "$description",
      "author": "$author",
      "variables": {
        "primary-color": "#3b82f6",
        "secondary-color": "#8b5cf6",
        "background-color": "#ffffff",
        "text-color": "#1f2937",
        "border-color": "#e5e7eb",
        "font-family": "sans-serif",
        "font-size-base": "16px",
        "border-radius": "0.5rem"
      }
    }
    THEME_EOF
      
      echo
      echo "Theme created: $theme_file"
      echo "Edit the file to customize variables"
    }
    
    # Delete theme
    delete_theme() {
      local theme_name="$1"
      local theme_file="$THEMES_DIR/$theme_name.json"
      
      if [[ ! -f "$theme_file" ]]; then
        echo "Error: Theme '$theme_name' not found"
        return 1
      fi
      
      # Prevent deleting builtin themes
      if [[ " ${lib.concatStringsSep " " (lib.attrNames builtinThemes)} " =~ " $theme_name " ]]; then
        echo "Error: Cannot delete builtin theme '$theme_name'"
        return 1
      fi
      
      read -p "Delete theme '$theme_name'? (y/N): " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f "$theme_file"
        rm -f "$CACHE_DIR/$theme_name.css"
        echo "Theme deleted: $theme_name"
      else
        echo "Cancelled"
      fi
    }
    
    # Export theme
    export_theme() {
      local theme_name="$1"
      local output_file="''${2:-$theme_name.json}"
      local theme_file="$THEMES_DIR/$theme_name.json"
      
      if [[ ! -f "$theme_file" ]]; then
        echo "Error: Theme '$theme_name' not found"
        return 1
      fi
      
      cp "$theme_file" "$output_file"
      echo "Theme exported: $output_file"
    }
    
    # Import theme
    import_theme() {
      local import_file="$1"
      
      if [[ ! -f "$import_file" ]]; then
        echo "Error: File not found: $import_file"
        return 1
      fi
      
      # Validate JSON
      if ! ${pkgs.jq}/bin/jq '.' "$import_file" >/dev/null 2>&1; then
        echo "Error: Invalid JSON file"
        return 1
      fi
      
      local theme_name=$(basename "$import_file" .json)
      local theme_file="$THEMES_DIR/$theme_name.json"
      
      if [[ -f "$theme_file" ]]; then
        read -p "Theme '$theme_name' exists. Overwrite? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
          echo "Cancelled"
          return 1
        fi
      fi
      
      cp "$import_file" "$theme_file"
      echo "Theme imported: $theme_name"
    }
    
    # Preview theme (generate HTML preview)
    preview_theme() {
      local theme_name="$1"
      local preview_file="$CACHE_DIR/$theme_name-preview.html"
      
      # Generate CSS
      generate_css "$theme_name" "$CACHE_DIR/$theme_name.css"
      
      # Generate preview HTML
      cat > "$preview_file" <<'HTML_EOF'
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Theme Preview: $theme_name</title>
      <link rel="stylesheet" href="$theme_name.css">
    </head>
    <body>
      <h1>Theme Preview: $theme_name</h1>
      
      <div class="step-container">
        <div class="step-header">Step 1: Example Step</div>
        <div class="step-metadata">Timestamp: 2026-01-02 14:30:00</div>
        <img src="data:image/svg+xml,%3Csvg width='800' height='600' xmlns='http://www.w3.org/2000/svg'%3E%3Crect width='800' height='600' fill='%23f0f0f0'/%3E%3Ctext x='400' y='300' text-anchor='middle' font-size='24' fill='%23333'%3EScreenshot Placeholder%3C/text%3E%3C/svg%3E" class="step-screenshot" alt="Screenshot" />
      </div>
      
      <div class="step-container">
        <div class="step-header">Step 2: Another Step</div>
        <div class="step-metadata">Timestamp: 2026-01-02 14:31:00</div>
        <p>This is an example step with some text content.</p>
      </div>
    </body>
    </html>
    HTML_EOF
      
      echo "Preview generated: $preview_file"
      
      # Open in browser
      ${pkgs.xdg-utils}/bin/xdg-open "$preview_file" 2>/dev/null || echo "Open manually: $preview_file"
    }
    
    # Command handling
    case "''${1:-list}" in
      list)
        init_builtin_themes
        list_themes
        ;;
      show)
        show_theme "''${2:-default}"
        ;;
      generate)
        generate_css "''${2:-default}" "''${3:-}"
        ;;
      create)
        create_theme "''${2:?Theme name required}"
        ;;
      delete)
        delete_theme "''${2:?Theme name required}"
        ;;
      export)
        export_theme "''${2:?Theme name required}" "''${3:-}"
        ;;
      import)
        import_theme "''${2:?File path required}"
        ;;
      preview)
        preview_theme "''${2:-default}"
        ;;
      init)
        init_builtin_themes
        echo "Builtin themes initialized in $THEMES_DIR"
        ;;
      *)
        echo "Usage: $0 {list|show|generate|create|delete|export|import|preview|init} [args]"
        echo
        echo "Commands:"
        echo "  list                    - List all available themes"
        echo "  show <name>             - Show theme details"
        echo "  generate <name> [file]  - Generate CSS from theme"
        echo "  create <name>           - Create new custom theme"
        echo "  delete <name>           - Delete custom theme"
        echo "  export <name> [file]    - Export theme to file"
        echo "  import <file>           - Import theme from file"
        echo "  preview <name>          - Generate HTML preview"
        echo "  init                    - Initialize builtin themes"
        exit 1
        ;;
    esac
  '';
  
  # Theme integration functions
  integrationFunctions = ''
    # Theme system integration
    
    apply_theme() {
      local theme_name="''${1:-default}"
      local output_dir="''${2:-$SESSION_DIR}"
      
      # Generate theme CSS
      chronicle-themes generate "$theme_name" "$output_dir/theme.css"
    }
    
    get_theme_css() {
      local theme_name="''${1:-default}"
      local css_file="''${XDG_CACHE_HOME:-$HOME/.cache}/nixos-chronicle/themes/$theme_name.css"
      
      if [[ ! -f "$css_file" ]]; then
        chronicle-themes generate "$theme_name" "$css_file" >/dev/null 2>&1
      fi
      
      cat "$css_file"
    }
  '';
}
