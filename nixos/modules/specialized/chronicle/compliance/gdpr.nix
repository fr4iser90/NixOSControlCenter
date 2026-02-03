{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.compliance.gdpr;
in
{
  options.services.chronicle.compliance.gdpr = {
    enable = mkEnableOption "GDPR compliance mode";

    dataMinimization = mkOption {
      type = types.bool;
      default = true;
      description = "Enable data minimization (collect only necessary data)";
    };

    consentTracking = mkOption {
      type = types.bool;
      default = true;
      description = "Track user consent for data collection";
    };

    rightToErasure = mkOption {
      type = types.bool;
      default = true;
      description = "Enable right to erasure functionality";
    };

    dataRetentionDays = mkOption {
      type = types.int;
      default = 90;
      description = "Days to retain data before automatic deletion";
    };

    exportUserData = mkOption {
      type = types.bool;
      default = true;
      description = "Enable user data export functionality";
    };

    privacyPolicyPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to privacy policy document";
    };

    consentLogPath = mkOption {
      type = types.path;
      default = "/var/log/chronicle/gdpr-consent.log";
      description = "Path to consent tracking log";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "chronicle-gdpr-consent" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # GDPR Consent Tracking
      CONSENT_LOG="${cfg.consentLogPath}"
      mkdir -p "$(dirname "$CONSENT_LOG")"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import json
      import sys
      import os
      from datetime import datetime

      def log_consent(user, purpose, granted):
          """Log user consent for GDPR compliance"""
          log_path = os.environ.get('CONSENT_LOG')
          
          consent_entry = {
              'timestamp': datetime.now().isoformat(),
              'user': user,
              'purpose': purpose,
              'consent_granted': granted,
              'ip_address': os.environ.get('SSH_CLIENT', 'local').split()[0] if os.environ.get('SSH_CLIENT') else 'local'
          }
          
          try:
              with open(log_path, 'a') as f:
                  f.write(json.dumps(consent_entry) + '\n')
              print(f"Consent logged: {user} - {purpose} - {'granted' if granted else 'denied'}")
          except Exception as e:
              print(f"Error logging consent: {e}", file=sys.stderr)
              sys.exit(1)

      if __name__ == "__main__":
          if len(sys.argv) < 4:
              print("Usage: gdpr-consent.sh <user> <purpose> <granted>", file=sys.stderr)
              sys.exit(1)
          
          user = sys.argv[1]
          purpose = sys.argv[2]
          granted = sys.argv[3].lower() in ['true', 'yes', '1']
          
          log_consent(user, purpose, granted)
      PYTHON_EOF
      '')
      (pkgs.writeShellScriptBin "chronicle-gdpr-erasure" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # GDPR Right to Erasure
      USER="$1"
      DATA_DIR="$HOME/.local/share/chronicle"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import os
      import sys
      import shutil
      import json
      from datetime import datetime

      def erase_user_data(user, data_dir):
          """Erase all user data in compliance with GDPR"""
          user_sessions = os.path.join(data_dir, 'sessions', user)
          user_exports = os.path.join(data_dir, 'exports', user)
          
          deleted_items = []
          
          # Delete user sessions
          if os.path.exists(user_sessions):
              shutil.rmtree(user_sessions)
              deleted_items.append(user_sessions)
          
          # Delete user exports
          if os.path.exists(user_exports):
              shutil.rmtree(user_exports)
              deleted_items.append(user_exports)
          
          # Log erasure
          erasure_log = {
              'timestamp': datetime.now().isoformat(),
              'user': user,
              'action': 'data_erasure',
              'deleted_items': deleted_items
          }
          
          log_path = '/var/log/chronicle/gdpr-erasure.log'
          os.makedirs(os.path.dirname(log_path), exist_ok=True)
          
          with open(log_path, 'a') as f:
              f.write(json.dumps(erasure_log) + '\n')
          
          print(f"User data erased for: {user}")
          print(f"Deleted {len(deleted_items)} item(s)")
          
      if __name__ == "__main__":
          if len(sys.argv) < 2:
              print("Usage: gdpr-erasure.sh <user>", file=sys.stderr)
              sys.exit(1)
          
          user = sys.argv[1]
          data_dir = os.environ.get('DATA_DIR', os.path.expanduser('~/.local/share/chronicle'))
          
          erase_user_data(user, data_dir)
      PYTHON_EOF
      '')
      (pkgs.writeShellScriptBin "chronicle-gdpr-export" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # GDPR Data Export
      USER="$1"
      OUTPUT_DIR="''${2:-/tmp/gdpr-export-$USER}"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import os
      import sys
      import json
      import shutil
      from datetime import datetime
      import tarfile

      def export_user_data(user, output_dir):
          """Export all user data for GDPR compliance"""
          data_dir = os.path.expanduser('~/.local/share/chronicle')
          user_sessions = os.path.join(data_dir, 'sessions', user)
          
          os.makedirs(output_dir, exist_ok=True)
          
          # Create export manifest
          manifest = {
              'export_date': datetime.now().isoformat(),
              'user': user,
              'gdpr_export': True,
              'data_types': []
          }
          
          # Copy sessions
          if os.path.exists(user_sessions):
              dest = os.path.join(output_dir, 'sessions')
              shutil.copytree(user_sessions, dest)
              manifest['data_types'].append('sessions')
          
          # Write manifest
          with open(os.path.join(output_dir, 'manifest.json'), 'w') as f:
              json.dump(manifest, f, indent=2)
          
          # Create tarball
          tarball_path = f"{output_dir}.tar.gz"
          with tarfile.open(tarball_path, "w:gz") as tar:
              tar.add(output_dir, arcname=os.path.basename(output_dir))
          
          print(f"User data exported to: {tarball_path}")
          
      if __name__ == "__main__":
          if len(sys.argv) < 2:
              print("Usage: gdpr-export.sh <user> [output_dir]", file=sys.stderr)
              sys.exit(1)
          
          user = sys.argv[1]
          output_dir = sys.argv[2] if len(sys.argv) > 2 else f"/tmp/gdpr-export-{user}"
          
          export_user_data(user, output_dir)
      PYTHON_EOF
      '')
    ];

    # Auto-deletion systemd timer
    systemd.timers."chronicle-gdpr-cleanup" = mkIf cfg.dataRetentionDays > 0 {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    systemd.services."chronicle-gdpr-cleanup" = mkIf cfg.dataRetentionDays > 0 {
      script = ''
        # Delete data older than retention period
        ${pkgs.findutils}/bin/find ~/.local/share/chronicle/sessions \
          -type f -mtime +${toString cfg.dataRetentionDays} -delete
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };
  };
}
