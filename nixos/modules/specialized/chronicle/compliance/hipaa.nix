{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.compliance.hipaa;
in
{
  options.services.chronicle.compliance.hipaa = {
    enable = mkEnableOption "HIPAA compliance mode";

    phiDetection = mkOption {
      type = types.bool;
      default = true;
      description = "Enable PHI (Protected Health Information) detection";
    };

    accessLogging = mkOption {
      type = types.bool;
      default = true;
      description = "Log all data access for audit trail";
    };

    encryptionRequired = mkOption {
      type = types.bool;
      default = true;
      description = "Require encryption for all data";
    };

    retentionYears = mkOption {
      type = types.int;
      default = 6;
      description = "Years to retain data (HIPAA minimum is 6)";
    };

    auditLogPath = mkOption {
      type = types.path;
      default = "/var/log/chronicle/hipaa-audit.log";
      description = "Path to HIPAA audit log";
    };
  };

  config = mkIf cfg.enable {
    # Enforce encryption when HIPAA mode is enabled
    services.chronicle.privacy.encryption.enable = mkIf cfg.encryptionRequired true;

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "chronicle-hipaa-audit" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # HIPAA Audit Logging
      AUDIT_LOG="${cfg.auditLogPath}"
      mkdir -p "$(dirname "$AUDIT_LOG")"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import json
      import sys
      import os
      from datetime import datetime

      def log_access(user, resource, action, result):
          """Log data access for HIPAA audit trail"""
          log_path = os.environ.get('AUDIT_LOG')
          
          audit_entry = {
              'timestamp': datetime.now().isoformat(),
              'user': user,
              'resource': resource,
              'action': action,
              'result': result,
              'source_ip': os.environ.get('SSH_CLIENT', 'local').split()[0] if os.environ.get('SSH_CLIENT') else 'local'
          }
          
          try:
              with open(log_path, 'a') as f:
                  f.write(json.dumps(audit_entry) + '\n')
          except Exception as e:
              print(f"Error logging audit entry: {e}", file=sys.stderr)
              sys.exit(1)

      if __name__ == "__main__":
          if len(sys.argv) < 5:
              print("Usage: hipaa-audit.sh <user> <resource> <action> <result>", file=sys.stderr)
              sys.exit(1)
          
          user = sys.argv[1]
          resource = sys.argv[2]
          action = sys.argv[3]
          result = sys.argv[4]
          
          log_access(user, resource, action, result)
          print(f"Audit logged: {user} - {action} - {resource} - {result}")
      PYTHON_EOF
      '')
      (pkgs.writeShellScriptBin "chronicle-phi-detect" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # PHI Detection
      INPUT_FILE="$1"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import re
      import sys
      import os

      # PHI patterns
      PHI_PATTERNS = {
          'SSN': r'\b\d{3}-\d{2}-\d{4}\b',
          'MRN': r'\b(MRN|Medical Record)[\s:]?\d{6,10}\b',
          'HEALTH_PLAN': r'\b(Policy|Member ID)[\s:]?\d{9,12}\b',
          'DOB': r'\b\d{1,2}/\d{1,2}/\d{4}\b',
          'NAME': r'\b([A-Z][a-z]+\s+){1,2}[A-Z][a-z]+\b',
      }

      def detect_phi(text):
          """Detect Protected Health Information"""
          matches = []
          for name, pattern in PHI_PATTERNS.items():
              for match in re.finditer(pattern, text):
                  matches.append({
                      'type': name,
                      'value': match.group(),
                      'position': match.start()
                  })
          return matches

      if __name__ == "__main__":
          if len(sys.argv) < 2:
              print("Usage: phi-detect.sh <file>", file=sys.stderr)
              sys.exit(1)
          
          file_path = sys.argv[1]
          
          with open(file_path, 'r') as f:
              content = f.read()
          
          phi_matches = detect_phi(content)
          
          if phi_matches:
              print(f"WARNING: Detected {len(phi_matches)} potential PHI instances")
              for match in phi_matches:
                  print(f"  {match['type']}: {match['value'][:20]}...")
              sys.exit(1)
          else:
              print("No PHI detected")
              sys.exit(0)
      PYTHON_EOF
      '')
    ];
  };
}
