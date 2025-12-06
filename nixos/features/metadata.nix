# Feature Metadata
# Defines dependencies and conflicts for all features

{
  features = {
    # "system-updater" removed (now core/system-updater)
    "system-checks" = {
      dependencies = [];  # cli-formatter is Core, no dependency needed
      conflicts = [];
    };
    "system-logger" = {
      dependencies = [];  # cli-formatter is Core, no dependency needed
      conflicts = [];
    };
    "ssh-client-manager" = {
      dependencies = [];  # cli-formatter is Core, no dependency needed
      conflicts = [];
    };
    "ssh-server-manager" = {
      dependencies = [];  # cli-formatter and command-center are Core, no dependencies needed
      conflicts = [];
    };
    # "command-center" removed (now core/command-center)
    "system-config-manager" = {
      dependencies = [];
      conflicts = [];
    };
    "system-discovery" = {
      dependencies = [];  # cli-formatter and command-center are Core, no dependencies needed
      conflicts = [];
    };
    "bootentry-manager" = {
      dependencies = [];
      conflicts = [];
    };
    "homelab-manager" = {
      dependencies = [];
      conflicts = [];
    };
    "vm-manager" = {
      dependencies = [];
      conflicts = [];
    };
    "ai-workspace" = {
      dependencies = [];
      conflicts = [];
    };
    "hackathon-manager" = {
      dependencies = [];
      conflicts = [];
    };
    # "terminal-ui" removed (now core/cli-formatter)
  };
}

