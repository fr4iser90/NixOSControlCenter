{ config, lib, pkgs, ... }:

let
  cfg = config.systemConfig.modules.specialized.chronicle.plugins;
  
  # Plugin manager script
  pluginManagerScript = pkgs.writeShellScriptBin "chronicle-plugins" ''
    #!/usr/bin/env bash
    # Plugin Manager for Step Recorder
    set -e
    
    PLUGINS_DIR="${cfg.pluginsDirectory}"
    MARKETPLACE_URL="${cfg.marketplaceUrl}"
    
    show_usage() {
      cat << EOF
    Usage: chronicle-plugins [COMMAND] [OPTIONS]
    
    Manage plugins for Step Recorder.
    
    Commands:
      list                         List installed plugins
      search <query>               Search marketplace for plugins
      install <plugin-name>        Install a plugin
      uninstall <plugin-name>      Uninstall a plugin
      enable <plugin-name>         Enable a plugin
      disable <plugin-name>        Disable a plugin
      info <plugin-name>           Show plugin information
      update [plugin-name]         Update plugin(s)
      
    Options:
      --version <ver>              Specify plugin version
      --force                      Force install/uninstall
      
    Examples:
      # List installed plugins
      chronicle-plugins list
      
      # Search for plugins
      chronicle-plugins search "screenshot"
      
      # Install a plugin
      chronicle-plugins install awesome-formatter
      
      # Update all plugins
      chronicle-plugins update
    EOF
    }
    
    # Initialize plugins directory
    init_plugins_dir() {
      mkdir -p "$PLUGINS_DIR"/{installed,enabled,disabled}
    }
    
    # List installed plugins
    list_plugins() {
      init_plugins_dir
      
      echo "Installed Plugins:"
      echo "═════════════════════════════════════════"
      echo ""
      
      local plugin_count=0
      
      if [ -d "$PLUGINS_DIR/installed" ]; then
        for plugin_dir in "$PLUGINS_DIR/installed"/*; do
          if [ -d "$plugin_dir" ]; then
            local plugin_name=$(basename "$plugin_dir")
            local version="1.0.0"
            local status="disabled"
            
            if [ -L "$PLUGINS_DIR/enabled/$plugin_name" ]; then
              status="enabled"
            fi
            
            echo "📦 $plugin_name (v$version) - $status"
            plugin_count=$((plugin_count + 1))
          fi
        done
      fi
      
      if [ "$plugin_count" -eq 0 ]; then
        echo "No plugins installed."
        echo ""
        echo "Search for plugins with: chronicle-plugins search <query>"
      fi
      
      echo ""
      echo "Total: $plugin_count plugins"
    }
    
    # Search marketplace
    search_marketplace() {
      local query="$1"
      
      echo "Searching marketplace for: $query"
      echo "═════════════════════════════════════════"
      echo ""
      
      # Placeholder - in production, would query actual marketplace
      cat << 'EOF'
    📦 screenshot-enhancer (v1.2.0)
       Enhanced screenshot processing with filters
       Author: StepRecorder Community
       Downloads: 1,234
       
    📦 pdf-advanced (v2.1.0)
       Advanced PDF generation with templates
       Author: PDF Team
       Downloads: 856
       
    📦 ai-summarizer (v0.9.0)
       AI-powered session summarization
       Author: AI Labs
       Downloads: 432
       
    EOF
      
      echo ""
      echo "Install with: chronicle-plugins install <plugin-name>"
    }
    
    # Install plugin
    install_plugin() {
      local plugin_name="$1"
      
      init_plugins_dir
      
      echo "Installing plugin: $plugin_name"
      echo "Source: $MARKETPLACE_URL"
      
      # Create plugin directory
      local plugin_dir="$PLUGINS_DIR/installed/$plugin_name"
      mkdir -p "$plugin_dir"
      
      # Create basic plugin structure (placeholder)
      cat > "$plugin_dir/plugin.json" << EOF
    {
      "name": "$plugin_name",
      "version": "1.0.0",
      "description": "Plugin: $plugin_name",
      "author": "Unknown",
      "entry": "main.sh"
    }
    EOF
      
      cat > "$plugin_dir/main.sh" << 'EOF'
    #!/usr/bin/env bash
    echo "Plugin executed"
    EOF
      
      chmod +x "$plugin_dir/main.sh"
      
      echo ""
      echo "✅ Plugin installed: $plugin_name"
      echo "   Enable with: chronicle-plugins enable $plugin_name"
    }
    
    # Uninstall plugin
    uninstall_plugin() {
      local plugin_name="$1"
      
      echo "Uninstalling plugin: $plugin_name"
      
      # Disable first if enabled
      if [ -L "$PLUGINS_DIR/enabled/$plugin_name" ]; then
        rm "$PLUGINS_DIR/enabled/$plugin_name"
      fi
      
      # Remove plugin directory
      if [ -d "$PLUGINS_DIR/installed/$plugin_name" ]; then
        rm -rf "$PLUGINS_DIR/installed/$plugin_name"
        echo "✅ Plugin uninstalled: $plugin_name"
      else
        echo "Error: Plugin not found: $plugin_name" >&2
        exit 1
      fi
    }
    
    # Enable plugin
    enable_plugin() {
      local plugin_name="$1"
      
      if [ ! -d "$PLUGINS_DIR/installed/$plugin_name" ]; then
        echo "Error: Plugin not installed: $plugin_name" >&2
        exit 1
      fi
      
      ln -sf "$PLUGINS_DIR/installed/$plugin_name" "$PLUGINS_DIR/enabled/$plugin_name"
      echo "✅ Plugin enabled: $plugin_name"
    }
    
    # Disable plugin
    disable_plugin() {
      local plugin_name="$1"
      
      if [ -L "$PLUGINS_DIR/enabled/$plugin_name" ]; then
        rm "$PLUGINS_DIR/enabled/$plugin_name"
        echo "✅ Plugin disabled: $plugin_name"
      else
        echo "Plugin not enabled: $plugin_name"
      fi
    }
    
    # Show plugin info
    show_plugin_info() {
      local plugin_name="$1"
      local plugin_dir="$PLUGINS_DIR/installed/$plugin_name"
      
      if [ ! -d "$plugin_dir" ]; then
        echo "Error: Plugin not found: $plugin_name" >&2
        exit 1
      fi
      
      if [ -f "$plugin_dir/plugin.json" ]; then
        echo "Plugin Information:"
        echo "═════════════════════════════════════════"
        ${pkgs.jq}/bin/jq '.' "$plugin_dir/plugin.json"
      else
        echo "No plugin metadata found"
      fi
    }
    
    # Main command dispatcher
    case "''${1:-}" in
      list)
        list_plugins
        ;;
      search)
        search_marketplace "$2"
        ;;
      install)
        install_plugin "$2"
        ;;
      uninstall)
        uninstall_plugin "$2"
        ;;
      enable)
        enable_plugin "$2"
        ;;
      disable)
        disable_plugin "$2"
        ;;
      info)
        show_plugin_info "$2"
        ;;
      update)
        echo "Plugin update not yet implemented" >&2
        exit 1
        ;;
      -h|--help|help)
        show_usage
        ;;
      *)
        show_usage
        exit 1
        ;;
    esac
  '';
in
{
  options.systemConfig.modules.specialized.chronicle.plugins = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable plugin system";
    };
    
    pluginsDirectory = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/chronicle/plugins";
      description = "Directory for installed plugins";
    };
    
    marketplaceUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://plugins.chronicle.org";
      description = "Plugin marketplace URL";
    };
    
    autoUpdate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically update plugins";
    };
    
    enableMarketplace = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable plugin marketplace integration";
    };
    
    allowThirdParty = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow third-party plugins (security consideration)";
    };
    
    sandboxPlugins = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run plugins in sandboxed environment";
    };
  };
  
  config = lib.mkIf (config.systemConfig.modules.specialized.chronicle.enable && cfg.enable) {
    environment.systemPackages = [ pluginManagerScript ];
  };
}
