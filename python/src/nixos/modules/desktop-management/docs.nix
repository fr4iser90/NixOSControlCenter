# modules/desktop/docs.nix
{
  meta = {
    description = "Desktop environment configuration module";
    maintainers = ["${systemConfig.mainUser}"];
    documentation = ./docs/README.md;
  };
}