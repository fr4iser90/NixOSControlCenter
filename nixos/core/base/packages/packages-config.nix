{
  allowUnfree = true;
  # Package modules directly
  packageModules = [
  #  "gaming"
  #  "streaming"
  #  "emulation"
  #  "game-dev"
  #  "web-dev"
  ];

  system = {
    packages = {
      enable = true;
      preset = null;
    };
  };
}
