{
  core = {
    cli-formatter = {
      enable = true;  # CLI formatter is always enabled as infrastructure

      # Configuration options
      config = {
        # Colors theme
        # theme = "dark";  # "light" or "dark"

        # Formatting options
        # enableUnicode = true;  # Enable Unicode symbols
        # tableStyle = "unicode";  # "ascii", "unicode", "markdown"
      };

      # Custom components (optional)
      components = {
        # Example custom component
        # myStatusBox = {
        #   enable = true;
        #   refreshInterval = 10;
        #   template = ''
        #     ${config.systemconfig.core.management.nixos-control-center.submodules.cli-formatter.api.boxes.primary {
        #       title = "My Status";
        #       content = "System is running smoothly!";
        #     }}
        #   '';
        # };
      };
    };
  };
}
