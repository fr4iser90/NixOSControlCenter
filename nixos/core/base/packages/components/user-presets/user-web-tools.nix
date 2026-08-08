# User-scoped preset: personal web/JS tools → users.<you>.userPackages
{
  description = "Personal web/JS tools (vscode, node, …) — current user only";
  systemTypes = [ "desktop" "server" ];
  scope = "user";
  packages = [
    "vscode"
    "nodejs"
    "yarn"
    "pnpm"
    "deno"
    "httpie"
    "sqlite"
  ];
}
