{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.security.validation;
in
{
  options.services.chronicle.security.validation = {
    enable = mkEnableOption "input validation and sanitization";

    strictMode = mkOption {
      type = types.bool;
      default = true;
      description = "Enable strict validation (reject invalid input)";
    };

    pathTraversalProtection = mkOption {
      type = types.bool;
      default = true;
      description = "Prevent path traversal attacks";
    };

    commandInjectionProtection = mkOption {
      type = types.bool;
      default = true;
      description = "Prevent command injection attacks";
    };

    xssProtection = mkOption {
      type = types.bool;
      default = true;
      description = "Sanitize HTML output to prevent XSS";
    };

    maxSessionNameLength = mkOption {
      type = types.int;
      default = 255;
      description = "Maximum session name length";
    };

    maxCommentLength = mkOption {
      type = types.int;
      default = 1000;
      description = "Maximum comment length";
    };

    allowedFileExtensions = mkOption {
      type = types.listOf types.str;
      default = [ "png" "jpg" "jpeg" "json" "html" "md" "zip" "pdf" "mp4" "webm" "opus" ];
      description = "Allowed file extensions";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "chronicle-validate" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Input Validation and Sanitization
      STRICT_MODE="${if cfg.strictMode then "true" else "false"}"
      MAX_SESSION_NAME="${toString cfg.maxSessionNameLength}"
      MAX_COMMENT="${toString cfg.maxCommentLength}"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import re
      import sys
      import os
      import html
      from pathlib import Path

      class ValidationError(Exception):
          """Validation error"""
          pass

      class InputValidator:
          """Input validation and sanitization"""
          
          ALLOWED_EXTENSIONS = ${builtins.toJSON cfg.allowedFileExtensions}
          MAX_SESSION_NAME = int(os.environ.get('MAX_SESSION_NAME', '255'))
          MAX_COMMENT = int(os.environ.get('MAX_COMMENT', '1000'))
          STRICT_MODE = os.environ.get('STRICT_MODE', 'true') == 'true'
          
          # Dangerous patterns
          PATH_TRAVERSAL_PATTERN = re.compile(r'\.\.|/\.|~/')
          COMMAND_INJECTION_PATTERN = re.compile(r'[;&|`$(){}[\]<>]')
          SQL_INJECTION_PATTERN = re.compile(r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|WHERE|OR|AND)\b)", re.IGNORECASE)
          
          @classmethod
          def validate_path(cls, path_str: str, allow_create: bool = False) -> Path:
              """Validate file path and prevent traversal attacks"""
              if ${if cfg.pathTraversalProtection then "True" else "False"}:
                  # Check for path traversal patterns
                  if cls.PATH_TRAVERSAL_PATTERN.search(path_str):
                      raise ValidationError(f"Path traversal detected: {path_str}")
                  
                  # Resolve to absolute path
                  try:
                      path = Path(path_str).resolve()
                  except Exception as e:
                      raise ValidationError(f"Invalid path: {e}")
                  
                  # Check if path is within allowed directories
                  allowed_dirs = [
                      Path.home() / '.local' / 'share' / 'chronicle',
                      Path.home() / '.config' / 'chronicle',
                      Path('/tmp'),
                      Path('/var/log/chronicle'),
                  ]
                  
                  if not any(path.is_relative_to(d) for d in allowed_dirs if d.exists()):
                      if cls.STRICT_MODE:
                          raise ValidationError(f"Path outside allowed directories: {path}")
                  
                  # Check file exists (unless we're creating)
                  if not allow_create and not path.exists():
                      raise ValidationError(f"Path does not exist: {path}")
                  
                  return path
              else:
                  return Path(path_str)
          
          @classmethod
          def validate_filename(cls, filename: str) -> str:
              """Validate filename and extension"""
              # Check for dangerous characters
              if re.search(r'[/\\:]', filename):
                  raise ValidationError(f"Invalid characters in filename: {filename}")
              
              # Check extension
              ext = filename.split('.')[-1].lower()
              if ext not in cls.ALLOWED_EXTENSIONS:
                  if cls.STRICT_MODE:
                      raise ValidationError(f"File extension not allowed: {ext}")
              
              return filename
          
          @classmethod
          def sanitize_command(cls, command: str) -> str:
              """Sanitize command to prevent injection"""
              if ${if cfg.commandInjectionProtection then "True" else "False"}:
                  # Check for dangerous characters
                  if cls.COMMAND_INJECTION_PATTERN.search(command):
                      if cls.STRICT_MODE:
                          raise ValidationError(f"Dangerous characters in command: {command}")
                      else:
                          # Remove dangerous characters
                          command = cls.COMMAND_INJECTION_PATTERN.sub("", command)
              
              return command
          
          @classmethod
          def sanitize_html(cls, text: str) -> str:
              """Sanitize HTML to prevent XSS"""
              if ${if cfg.xssProtection then "True" else "False"}:
                  # Escape HTML entities
                  text = html.escape(text)
                  
                  # Remove script tags (case-insensitive)
                  text = re.sub(r'<script[^>]*>.*?</script>', "", text, flags=re.IGNORECASE | re.DOTALL)
                  
                  # Remove on* event handlers
                  text = re.sub(r'\s*on\w+\s*=\s*["\'][^"\']*["\']', "", text, flags=re.IGNORECASE)
              
              return text
          
          @classmethod
          def validate_session_name(cls, name: str) -> str:
              """Validate session name"""
              if not name or not name.strip():
                  raise ValidationError("Session name cannot be empty")
              
              name = name.strip()
              
              if len(name) > cls.MAX_SESSION_NAME:
                  if cls.STRICT_MODE:
                      raise ValidationError(f"Session name too long: {len(name)} > {cls.MAX_SESSION_NAME}")
                  else:
                      name = name[:cls.MAX_SESSION_NAME]
              
              # Remove dangerous characters
              name = re.sub(r'[/\\<>:"|?*]', "_", name)
              
              return name
          
          @classmethod
          def validate_comment(cls, comment: str) -> str:
              """Validate comment text"""
              if len(comment) > cls.MAX_COMMENT:
                  if cls.STRICT_MODE:
                      raise ValidationError(f"Comment too long: {len(comment)} > {cls.MAX_COMMENT}")
                  else:
                      comment = comment[:cls.MAX_COMMENT]
              
              return cls.sanitize_html(comment)
          
          @classmethod
          def validate_email(cls, email: str) -> str:
              """Validate email address"""
              email_pattern = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
              if not email_pattern.match(email):
                  raise ValidationError(f"Invalid email address: {email}")
              return email
          
          @classmethod
          def validate_url(cls, url: str) -> str:
              """Validate URL"""
              # Simple URL validation
              url_pattern = re.compile(
                  r'^https?://'  # http:// or https://
                  r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'  # domain
                  r'localhost|'  # localhost
                  r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'  # IP
                  r'(?::\d+)?'  # optional port
                  r'(?:/?|[/?]\S+)$', re.IGNORECASE)
              
              if not url_pattern.match(url):
                  raise ValidationError(f"Invalid URL: {url}")
              
              # Only allow HTTP/HTTPS
              if not url.startswith(('http://', 'https://')):
                  raise ValidationError(f"Only HTTP/HTTPS URLs allowed: {url}")
              
              return url

      def main():
          """CLI interface for validation"""
          if len(sys.argv) < 3:
              print("Usage: validate.sh <type> <value>", file=sys.stderr)
              print("Types: path, filename, command, html, session_name, comment, email, url", file=sys.stderr)
              sys.exit(1)
          
          validate_type = sys.argv[1]
          value = sys.argv[2]
          
          try:
              if validate_type == 'path':
                  result = InputValidator.validate_path(value)
                  print(result)
              elif validate_type == 'filename':
                  result = InputValidator.validate_filename(value)
                  print(result)
              elif validate_type == 'command':
                  result = InputValidator.sanitize_command(value)
                  print(result)
              elif validate_type == 'html':
                  result = InputValidator.sanitize_html(value)
                  print(result)
              elif validate_type == 'session_name':
                  result = InputValidator.validate_session_name(value)
                  print(result)
              elif validate_type == 'comment':
                  result = InputValidator.validate_comment(value)
                  print(result)
              elif validate_type == 'email':
                  result = InputValidator.validate_email(value)
                  print(result)
              elif validate_type == 'url':
                  result = InputValidator.validate_url(value)
                  print(result)
              else:
                  print(f"Unknown validation type: {validate_type}", file=sys.stderr)
                  sys.exit(1)
          except ValidationError as e:
              print(f"Validation error: {e}", file=sys.stderr)
              sys.exit(1)
          except Exception as e:
              print(f"Unexpected error: {e}", file=sys.stderr)
              sys.exit(2)

      if __name__ == '__main__':
          main()
      PYTHON_EOF
      '')
    ];
  };
}
