{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.security.rbac;
  
  roleType = types.submodule {
    options = {
      permissions = mkOption {
        type = types.listOf types.str;
        description = "List of permissions for this role";
      };
      inherits = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Roles to inherit permissions from";
      };
    };
  };
in
{
  options.services.chronicle.security.rbac = {
    enable = mkEnableOption "role-based access control";

    roles = mkOption {
      type = types.attrsOf roleType;
      default = {
        admin = {
          permissions = [
            "record.start"
            "record.stop"
            "record.pause"
            "step.create"
            "step.edit"
            "step.delete"
            "session.view"
            "session.export"
            "session.delete"
            "user.manage"
            "settings.modify"
          ];
          inherits = [];
        };
        recorder = {
          permissions = [
            "record.start"
            "record.stop"
            "record.pause"
            "step.create"
            "step.edit"
            "session.view"
            "session.export"
          ];
          inherits = [];
        };
        viewer = {
          permissions = [
            "session.view"
            "session.export"
          ];
          inherits = [];
        };
      };
      description = "Role definitions with permissions";
    };

    userRoles = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {};
      example = {
        "alice" = [ "admin" ];
        "bob" = [ "recorder" ];
        "charlie" = [ "viewer" ];
      };
      description = "User to role mappings";
    };

    aclPath = mkOption {
      type = types.path;
      default = "/etc/chronicle/acl.json";
      description = "Path to ACL configuration file";
    };
  };

  config = mkIf cfg.enable {
    # Generate ACL configuration file
    environment.etc."chronicle/acl.json".text = builtins.toJSON {
      roles = cfg.roles;
      userRoles = cfg.userRoles;
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "chronicle-rbac-check" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # RBAC Permission Check
      USER="$1"
      PERMISSION="$2"
      ACL_FILE="${cfg.aclPath}"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import json
      import sys
      import os

      def check_permission(user, permission, acl_file):
          """Check if user has permission"""
          try:
              with open(acl_file, 'r') as f:
                  acl = json.load(f)
          except FileNotFoundError:
              print(f"Error: ACL file not found: {acl_file}", file=sys.stderr)
              return False
          
          # Get user roles
          user_roles = acl.get('userRoles', {}).get(user, [])
          if not user_roles:
              print(f"User {user} has no roles assigned", file=sys.stderr)
              return False
          
          # Collect all permissions for user's roles (including inherited)
          all_permissions = set()
          roles = acl.get('roles', {})
          
          def collect_permissions(role_name, visited=None):
              if visited is None:
                  visited = set()
              if role_name in visited or role_name not in roles:
                  return
              visited.add(role_name)
              
              role = roles[role_name]
              all_permissions.update(role.get('permissions', []))
              
              # Recursively collect inherited permissions
              for inherited_role in role.get('inherits', []):
                  collect_permissions(inherited_role, visited)
          
          for role in user_roles:
              collect_permissions(role)
          
          # Check if permission exists
          has_permission = permission in all_permissions
          
          if has_permission:
              print(f"Permission granted: {user} -> {permission}")
              return True
          else:
              print(f"Permission denied: {user} -> {permission}", file=sys.stderr)
              return False

      if __name__ == "__main__":
          if len(sys.argv) < 3:
              print("Usage: rbac-check.sh <user> <permission>", file=sys.stderr)
              sys.exit(1)
          
          user = sys.argv[1]
          permission = sys.argv[2]
          acl_file = os.environ.get('ACL_FILE', '/etc/chronicle/acl.json')
          
          if check_permission(user, permission, acl_file):
              sys.exit(0)
          else:
              sys.exit(1)
      PYTHON_EOF
      '')
      (pkgs.writeShellScriptBin "chronicle-rbac-add-user" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Add user to role
      USER="$1"
      ROLE="$2"
      ACL_FILE="${cfg.aclPath}"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import json
      import sys
      import os

      def add_user_to_role(user, role, acl_file):
          """Add user to a role"""
          try:
              with open(acl_file, 'r') as f:
                  acl = json.load(f)
          except FileNotFoundError:
              acl = {'roles': {}, 'userRoles': {}}
          
          if role not in acl.get('roles', {}):
              print(f"Error: Role {role} does not exist", file=sys.stderr)
              return False
          
          if 'userRoles' not in acl:
              acl['userRoles'] = {}
          
          if user not in acl['userRoles']:
              acl['userRoles'][user] = []
          
          if role not in acl['userRoles'][user]:
              acl['userRoles'][user].append(role)
          
          with open(acl_file, 'w') as f:
              json.dump(acl, f, indent=2)
          
          print(f"Added {user} to role {role}")
          return True

      if __name__ == "__main__":
          if len(sys.argv) < 3:
              print("Usage: rbac-add-user.sh <user> <role>", file=sys.stderr)
              sys.exit(1)
          
          user = sys.argv[1]
          role = sys.argv[2]
          acl_file = os.environ.get('ACL_FILE', '/etc/chronicle/acl.json')
          
          if add_user_to_role(user, role, acl_file):
              sys.exit(0)
          else:
              sys.exit(1)
      PYTHON_EOF
      '')
    ];
  };
}
