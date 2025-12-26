# Homelab Manager TUI Menu Definition
# Defines the interactive menu structure for homelab management

{
  # Main menu configuration
  title = "🏠 Homelab Manager";
  subtitle = "Docker Swarm & Container Management";

  # Menu items with actions
  items = [
    {
      name = "📊 Status Overview";
      description = "Show current homelab status and running services";
      action = "status";
      key = "s";
      category = "information";
    }
    {
      name = "🚀 Initialize Swarm";
      description = "Initialize Docker Swarm as manager node";
      action = "init-swarm";
      key = "i";
      category = "setup";
    }
    {
      name = "🔗 Join Swarm";
      description = "Join existing Docker Swarm as worker/manager";
      action = "join-swarm";
      key = "j";
      category = "setup";
    }
    {
      name = "📦 Deploy Stack";
      description = "Deploy a Docker stack from compose file";
      action = "deploy-stack";
      key = "d";
      category = "deployment";
    }
    {
      name = "🗂️ List Stacks";
      description = "Show all deployed stacks and their status";
      action = "list-stacks";
      key = "l";
      category = "information";
    }
    {
      name = "🛑 Remove Stack";
      description = "Remove a deployed Docker stack";
      action = "remove-stack";
      key = "r";
      category = "deployment";
    }
    {
      name = "⚙️ Configure";
      description = "Configure homelab settings";
      action = "configure";
      key = "c";
      category = "configuration";
    }
    {
      name = "🔄 Update Services";
      description = "Update all services in deployed stacks";
      action = "update-services";
      key = "u";
      category = "maintenance";
    }
    {
      name = "📋 Service Logs";
      description = "Show logs for specific services";
      action = "logs";
      key = "g";
      category = "debugging";
    }
    {
      name = "🔍 Inspect Stack";
      description = "Detailed information about a specific stack";
      action = "inspect-stack";
      key = "n";
      category = "information";
    }
  ];

  # Categories for grouping menu items
  categories = {
    information = "ℹ️ Information";
    setup = "⚙️ Setup";
    deployment = "🚀 Deployment";
    configuration = "🔧 Configuration";
    maintenance = "🔄 Maintenance";
    debugging = "🐛 Debugging";
  };

  # Menu behavior configuration
  behavior = {
    showCategories = true;
    showKeys = true;
    allowSearch = true;
    searchPlaceholder = "Search homelab actions...";
    exitOnAction = false;  # Stay in menu after actions
  };

  # Help text
  help = ''
    Homelab Manager - Docker Swarm & Container Management

    Use ↑↓ to navigate, Enter to select, ESC to exit
    Type to search, or use shortcut keys shown in []

    Categories:
    • Information: Status and overview commands
    • Setup: Swarm initialization and joining
    • Deployment: Stack deployment and management
    • Configuration: Settings and configuration
    • Maintenance: Updates and maintenance tasks
    • Debugging: Logs and inspection tools
  '';
}
