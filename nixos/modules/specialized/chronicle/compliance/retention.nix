{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.compliance.retention;
in
{
  options.services.chronicle.compliance.retention = {
    enable = mkEnableOption "data retention policies";

    defaultRetentionDays = mkOption {
      type = types.int;
      default = 365;
      description = "Default retention period in days";
    };

    policies = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          retentionDays = mkOption {
            type = types.int;
            description = "Retention period in days";
          };
          
          autoArchive = mkOption {
            type = types.bool;
            default = false;
            description = "Archive before deletion";
          };
          
          archivePath = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Archive destination path";
          };
          
          notifyBeforeDays = mkOption {
            type = types.int;
            default = 7;
            description = "Days before deletion to send notification";
          };
        };
      });
      default = {
        sessions = {
          retentionDays = 365;
          autoArchive = true;
          archivePath = "/var/archive/chronicle/sessions";
          notifyBeforeDays = 30;
        };
        exports = {
          retentionDays = 90;
          autoArchive = false;
          notifyBeforeDays = 7;
        };
        logs = {
          retentionDays = 180;
          autoArchive = true;
          archivePath = "/var/archive/chronicle/logs";
          notifyBeforeDays = 14;
        };
      };
      description = "Retention policies for different data types";
    };

    legalHold = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "session-123" "session-456" ];
      description = "Sessions under legal hold (never deleted)";
    };

    cleanupSchedule = mkOption {
      type = types.str;
      default = "daily";
      description = "Systemd timer schedule for cleanup";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "chronicle-retention-cleanup" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Retention Policy Cleanup
      DATA_DIR="$HOME/.local/share/chronicle"
      POLICIES='${builtins.toJSON cfg.policies}'
      LEGAL_HOLD='${builtins.toJSON cfg.legalHold}'

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import os
      import sys
      import json
      import shutil
      import tarfile
      from datetime import datetime, timedelta
      from pathlib import Path

      def load_policies():
          """Load retention policies"""
          return json.loads(os.environ.get('POLICIES', '{}'))

      def load_legal_hold():
          """Load legal hold list"""
          return json.loads(os.environ.get('LEGAL_HOLD', '[]'))

      def is_legal_hold(session_id, legal_hold_list):
          """Check if session is under legal hold"""
          return session_id in legal_hold_list

      def archive_data(source_path, archive_path):
          """Archive data before deletion"""
          archive_dir = Path(archive_path)
          archive_dir.mkdir(parents=True, exist_ok=True)
          
          timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
          tarball_name = f"{source_path.name}_{timestamp}.tar.gz"
          tarball_path = archive_dir / tarball_name
          
          with tarfile.open(tarball_path, "w:gz") as tar:
              tar.add(source_path, arcname=source_path.name)
          
          return tarball_path

      def send_notification(message):
          """Send notification about upcoming deletion"""
          try:
              os.system(f'${pkgs.libnotify}/bin/notify-send "Step Recorder Retention" "{message}"')
          except Exception as e:
              print(f"Warning: Could not send notification: {e}", file=sys.stderr)

      def cleanup_data(data_type, policy):
          """Cleanup data according to retention policy"""
          data_dir = Path(os.environ.get('DATA_DIR', os.path.expanduser('~/.local/share/chronicle')))
          legal_hold = load_legal_hold()
          
          retention_days = policy['retentionDays']
          auto_archive = policy.get('autoArchive', False)
          archive_path = policy.get('archivePath')
          notify_before_days = policy.get('notifyBeforeDays', 7)
          
          cutoff_date = datetime.now() - timedelta(days=retention_days)
          notify_date = datetime.now() - timedelta(days=retention_days - notify_before_days)
          
          data_path = data_dir / data_type
          if not data_path.exists():
              return
          
          deleted_count = 0
          archived_count = 0
          notified_count = 0
          
          for item in data_path.iterdir():
              # Skip if under legal hold
              if is_legal_hold(item.name, legal_hold):
                  print(f"Skipping {item.name} (legal hold)")
                  continue
              
              # Check modification time
              mtime = datetime.fromtimestamp(item.stat().st_mtime)
              
              if mtime < cutoff_date:
                  # Archive if requested
                  if auto_archive and archive_path:
                      try:
                          archive_file = archive_data(item, archive_path)
                          print(f"Archived: {item} -> {archive_file}")
                          archived_count += 1
                      except Exception as e:
                          print(f"Error archiving {item}: {e}", file=sys.stderr)
                          continue
                  
                  # Delete
                  try:
                      if item.is_dir():
                          shutil.rmtree(item)
                      else:
                          item.unlink()
                      print(f"Deleted: {item}")
                      deleted_count += 1
                  except Exception as e:
                      print(f"Error deleting {item}: {e}", file=sys.stderr)
              
              elif mtime < notify_date:
                  # Send notification for upcoming deletion
                  days_until_deletion = (mtime - cutoff_date).days
                  send_notification(f"{data_type}/{item.name} will be deleted in {days_until_deletion} days")
                  notified_count += 1
          
          print(f"=== {data_type} Cleanup Summary ===")
          print(f"Deleted: {deleted_count}")
          print(f"Archived: {archived_count}")
          print(f"Notifications sent: {notified_count}")

      def main():
          """Main cleanup routine"""
          policies = load_policies()
          
          for data_type, policy in policies.items():
              print(f"\n=== Processing {data_type} ===")
              print(f"Retention: {policy['retentionDays']} days")
              
              try:
                  cleanup_data(data_type, policy)
              except Exception as e:
                  print(f"Error processing {data_type}: {e}", file=sys.stderr)
          
          print("\n=== Retention Cleanup Complete ===")

      if __name__ == '__main__':
          main()
      PYTHON_EOF
      '')
      (pkgs.writeShellScriptBin "chronicle-retention-status" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Retention Policy Status
      DATA_DIR="$HOME/.local/share/chronicle"
      POLICIES='${builtins.toJSON cfg.policies}'

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import os
      import json
      from datetime import datetime, timedelta
      from pathlib import Path

      def show_retention_status():
          """Show retention policy status"""
          data_dir = Path(os.environ.get('DATA_DIR', os.path.expanduser('~/.local/share/chronicle')))
          policies = json.loads(os.environ.get('POLICIES', '{}'))
          
          print("=== Retention Policy Status ===\n")
          
          for data_type, policy in policies.items():
              print(f"📁 {data_type.upper()}")
              print(f"   Retention: {policy['retentionDays']} days")
              print(f"   Auto-archive: {'Yes' if policy.get('autoArchive') else 'No'}")
              
              if policy.get('archivePath'):
                  print(f"   Archive path: {policy['archivePath']}")
              
              data_path = data_dir / data_type
              if data_path.exists():
                  items = list(data_path.iterdir())
                  total_size = sum(item.stat().st_size if item.is_file() else 
                                 sum(f.stat().st_size for f in item.rglob('*') if f.is_file())
                                 for item in items)
                  
                  retention_days = policy['retentionDays']
                  cutoff_date = datetime.now() - timedelta(days=retention_days)
                  
                  expired = sum(1 for item in items 
                              if datetime.fromtimestamp(item.stat().st_mtime) < cutoff_date)
                  
                  print(f"   Total items: {len(items)}")
                  print(f"   Total size: {total_size / 1024 / 1024:.2f} MB")
                  print(f"   Expired items: {expired}")
              else:
                  print(f"   No data found")
              
              print()

      if __name__ == '__main__':
          show_retention_status()
      PYTHON_EOF
      '')
    ];

    # Systemd timer for automatic cleanup
    systemd.timers."chronicle-retention-cleanup" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.cleanupSchedule;
        Persistent = true;
      };
    };

    systemd.services."chronicle-retention-cleanup" = {
      script = ''
        ${cfg.scripts.retentionCleanup or pkgs.writeShellScript "retention-cleanup.sh" "echo 'Retention cleanup not configured'"}
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "%u";
      };
    };
  };
}
