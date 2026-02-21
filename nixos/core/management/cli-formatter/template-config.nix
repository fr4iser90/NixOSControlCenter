{
  # Core module - always active (no enable option)
  # CLI formatter is essential infrastructure for all CLI output

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
    #     ${config.systemconfig.core.management.cli-formatter.api.boxes.primary {
    #       title = "My Status";
    #       content = "System is running smoothly!";
    #     }}
    #   '';
    # };
  };
}
