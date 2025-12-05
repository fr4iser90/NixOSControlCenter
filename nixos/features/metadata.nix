# Feature Metadata
# Defines dependencies and conflicts for all features

{
  features = {
    "system-updater" = {
      dependencies = [ "terminal-ui" "command-center" ];
      conflicts = [];
    };
    "system-checks" = {
      dependencies = [ "terminal-ui" ];
      conflicts = [];
    };
    "system-logger" = {
      dependencies = [ "terminal-ui" ];
      conflicts = [];
    };
    "ssh-client-manager" = {
      dependencies = [ "terminal-ui" ];
      conflicts = [];
    };
    "ssh-server-manager" = {
      dependencies = [ "terminal-ui" "command-center" ];
      conflicts = [];
    };
    "command-center" = {
      dependencies = [ "terminal-ui" ];
      conflicts = [];
    };
    "system-config-manager" = {
      dependencies = [];
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
    "terminal-ui" = {
      dependencies = [];
      conflicts = [];
    };
  };
}

