{ config, lib, pkgs, sshClientCfg, systemConfig, scriptPath }:

let
  tuiEngine = config.core.management.tui-engine;

    previewScript = import ../../scripts/ssh-connection-preview.nix {
      inherit pkgs sshClientCfg;
    };

    listScript = pkgs.writeScript "ncc-ssh-client-tui-list" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${pkgs.python3}/bin/python - <<'PY'
import json
import subprocess

items = [
    {
        "name": "Add new server",
        "description": "Add a new SSH server",
        "status": "action",
        "category": "ssh",
        "path": "add",
        "actions": [
            {
                "name": "add",
                "label": "Add server",
                "args": [
                    {"name": "ip", "prompt": "Server IP/hostname", "secret": False},
                    {"name": "user", "prompt": "Username", "secret": False},
                ],
            }
        ],
    },
]

import os

creds_path = os.path.expanduser("~/${sshClientCfg.credentialsFile}")
try:
    with open(creds_path, "r", encoding="utf-8") as f:
        output = f.read()
except FileNotFoundError:
    output = ""

for line in output.splitlines():
    line = line.strip()
    if not line:
        continue
    if "=" not in line:
        continue
    server, user = line.split("=", 1)
    server = server.strip()
    user = user.strip()
    if not server or not user:
        continue
    items.append({
        "name": f"{server} ({user})",
        "description": f"Saved server {server}",
        "status": "server",
        "category": "ssh",
        "path": server,
        "action": "connect",
        "args": [
            {"name": "ip", "prompt": "Server IP/hostname", "secret": False, "default": server},
            {"name": "user", "prompt": "Username", "secret": False, "default": user},
        ],
        "actions": [
            {
                "name": "connect",
                "label": "Connect",
                "args": [
                    {"name": "ip", "prompt": "Server IP/hostname", "secret": False, "default": server},
                    {"name": "user", "prompt": "Username", "secret": False, "default": user},
                ],
            },
            {
                "name": "edit",
                "label": "Edit user",
                "args": [
                    {"name": "ip", "prompt": "Server IP/hostname", "secret": False, "default": server},
                    {"name": "user", "prompt": "New username", "secret": False, "default": user},
                ],
            },
            {
                "name": "delete",
                "label": "Delete",
                "args": [
                    {"name": "ip", "prompt": "Server IP/hostname", "secret": False, "default": server},
                ],
            },
        ],
    })

print(json.dumps(items))
PY
  '';

  filterScript = pkgs.writeScript "ncc-ssh-client-tui-filter" ''
    #!${pkgs.bash}/bin/bash
    cat << 'EOF'
Domain: ssh-client-manager
Actions: add, connect, edit, delete
EOF
  '';

  detailsScript = pkgs.writeScript "ncc-ssh-client-tui-details" ''
    #!${pkgs.bash}/bin/bash
    if [ -n "${previewScript}/bin/ssh-connection-preview" ]; then
      ${previewScript}/bin/ssh-connection-preview "$1" 2>/dev/null || true
    else
      echo "Server Information"
    fi
  '';

  actionsScript = pkgs.writeScript "ncc-ssh-client-tui-actions" ''
    #!${pkgs.bash}/bin/bash
    cat << 'EOF'
enter  - connect
ctrl-x - delete
ctrl-e - edit
ctrl-n - new
EOF
  '';

  statsScript = pkgs.writeScript "ncc-ssh-client-tui-stats" ''
    #!${pkgs.bash}/bin/bash
    cat << 'EOF'
SSH Client:
- actions: add, connect, edit, delete
EOF
  '';

  sshClientTui = tuiEngine.createTuiScript {
    name = "ssh-client";
    title = "🔐 SSH Client Manager";
    getList = listScript;
    getFilter = filterScript;
    getDetails = detailsScript;
    getActions = actionsScript;
    getStats = statsScript;
    footer = "enter connect • ctrl-x delete • ctrl-e edit • ctrl-n new • q quit";
    actionCmd = "ncc ssh-client-manager {action} {arg:ip} {arg:user}";
    layout = "fzf";
    staticMenu = true;
  };
in
{
  tuiScript = sshClientTui;
}