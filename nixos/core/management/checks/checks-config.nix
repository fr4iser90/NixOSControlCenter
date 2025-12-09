{
  management = {
    checks = {
      # Management module - enabled by default, but can be disabled if needed
      enable = true;

      # Postbuild checks (run after system activation)
      postbuild = {
        enable = true;

        checks = {
          passwords.enable = true;     # Check admin passwords
          filesystem.enable = true;    # Check filesystem permissions
          services.enable = true;      # Check critical services
        };
      };

      # Prebuild checks (run before system build)
      prebuild = {
        enable = true;

        checks = {
          cpu.enable = true;           # Check CPU configuration
          gpu.enable = true;           # Check GPU configuration
          memory.enable = true;        # Check memory configuration
          users.enable = true;         # Check user configuration
        };
      };
    };
  };
}
