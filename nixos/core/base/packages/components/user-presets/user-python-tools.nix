# User-scoped preset: light Python tooling for one account
{
  description = "Personal Python tools (python312, black, ipython, …) — current user only";
  systemTypes = [ "desktop" "server" ];
  scope = "user";
  packages = [
    "python312"
    "black"
    "mypy"
    "ipython"
    "ruff"
  ];
}
