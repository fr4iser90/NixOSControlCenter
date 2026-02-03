{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.privacy.ocrRedaction;
in
{
  options.services.chronicle.privacy.ocrRedaction = {
    enable = mkEnableOption "OCR-based PII redaction for screenshots";

    engine = mkOption {
      type = types.enum [ "tesseract" "easyocr" ];
      default = "tesseract";
      description = "OCR engine to use";
    };

    piiPatterns = mkOption {
      type = types.listOf types.str;
      default = [
        "SSN"
        "CREDIT_CARD"
        "EMAIL"
        "PHONE"
        "IP_ADDRESS"
      ];
      description = "Types of PII to detect and redact";
    };

    customPatterns = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {
        "api_key" = "sk-[a-zA-Z0-9]{48}";
        "password" = "(?i)(password|pwd)\\s*[:=]\\s*\\S+";
      };
      description = "Custom regex patterns for redaction";
    };

    redactionStyle = mkOption {
      type = types.enum [ "blur" "black" "pixelate" "redacted_text" ];
      default = "blur";
      description = "Style of redaction to apply";
    };

    auditLog = mkOption {
      type = types.bool;
      default = true;
      description = "Log redaction events for audit trail";
    };

    auditLogPath = mkOption {
      type = types.path;
      default = "/var/log/chronicle/redactions.log";
      description = "Path to redaction audit log";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      tesseract
      (python3.withPackages (ps: with ps; [
        pytesseract
        pillow
        opencv4
        numpy
      ]))
      (pkgs.writeShellScriptBin "chronicle-ocr-redact" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # OCR Redaction Script
      # Detects and redacts PII from screenshots using OCR

      SCREENSHOT="$1"
      OUTPUT="''${2:-$SCREENSHOT}"
      AUDIT_LOG="${cfg.auditLogPath}"
      REDACTION_STYLE="${cfg.redactionStyle}"

      # Create audit log directory if needed
      mkdir -p "$(dirname "$AUDIT_LOG")"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import cv2
      import pytesseract
      import re
      import sys
      import os
      import json
      from datetime import datetime
      from PIL import Image
      import numpy as np

      # PII detection patterns
      PII_PATTERNS = {
          'SSN': r'\b\d{3}-\d{2}-\d{4}\b',
          'CREDIT_CARD': r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b',
          'EMAIL': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
          'PHONE': r'\b(\+\d{1,2}\s?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b',
          'IP_ADDRESS': r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',
      }

      # Custom patterns from config
      CUSTOM_PATTERNS = ${builtins.toJSON cfg.customPatterns}

      def detect_pii(text):
          """Detect PII in text and return matches with positions"""
          matches = []
          
          enabled_patterns = ${builtins.toJSON cfg.piiPatterns}
          
          for pattern_name in enabled_patterns:
              if pattern_name in PII_PATTERNS:
                  pattern = PII_PATTERNS[pattern_name]
                  for match in re.finditer(pattern, text):
                      matches.append({
                          'type': pattern_name,
                          'text': match.group(),
                          'start': match.start(),
                          'end': match.end()
                      })
          
          # Check custom patterns
          for name, pattern in CUSTOM_PATTERNS.items():
              for match in re.finditer(pattern, text):
                  matches.append({
                      'type': f'CUSTOM_{name}',
                      'text': match.group(),
                      'start': match.start(),
                      'end': match.end()
                  })
          
          return matches

      def apply_redaction(img, boxes, style='${cfg.redactionStyle}'):
          """Apply redaction to image at specified boxes"""
          for box in boxes:
              x, y, w, h = box
              
              if style == 'blur':
                  roi = img[y:y+h, x:x+w]
                  blurred = cv2.GaussianBlur(roi, (51, 51), 0)
                  img[y:y+h, x:x+w] = blurred
              elif style == 'black':
                  cv2.rectangle(img, (x, y), (x+w, y+h), (0, 0, 0), -1)
              elif style == 'pixelate':
                  roi = img[y:y+h, x:x+w]
                  temp = cv2.resize(roi, (10, 10), interpolation=cv2.INTER_LINEAR)
                  pixelated = cv2.resize(temp, (w, h), interpolation=cv2.INTER_NEAREST)
                  img[y:y+h, x:x+w] = pixelated
              elif style == 'redacted_text':
                  cv2.rectangle(img, (x, y), (x+w, y+h), (0, 0, 0), -1)
                  cv2.putText(img, '[REDACTED]', (x+5, y+h-5), 
                             cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
          
          return img

      def log_redaction(screenshot_path, redactions):
          """Log redaction events for audit trail"""
          audit_log = os.environ.get('AUDIT_LOG', '/var/log/chronicle/redactions.log')
          
          log_entry = {
              'timestamp': datetime.now().isoformat(),
              'screenshot': screenshot_path,
              'redactions': [
                  {'type': r['type'], 'count': 1} 
                  for r in redactions
              ]
          }
          
          try:
              with open(audit_log, 'a') as f:
                  f.write(json.dumps(log_entry) + '\n')
          except Exception as e:
              print(f"Warning: Could not write to audit log: {e}", file=sys.stderr)

      def redact_screenshot(image_path, output_path):
          """Perform OCR and redact PII from screenshot"""
          # Read image
          img = cv2.imread(image_path)
          if img is None:
              print(f"Error: Could not read image {image_path}", file=sys.stderr)
              return False
          
          # Perform OCR
          ocr_data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
          
          # Extract full text
          full_text = ' '.join([text for text in ocr_data['text'] if text.strip()])
          
          # Detect PII
          pii_matches = detect_pii(full_text)
          
          if not pii_matches:
              print(f"No PII detected in {image_path}")
              cv2.imwrite(output_path, img)
              return True
          
          # Find text boxes to redact
          redaction_boxes = []
          for match in pii_matches:
              # Find corresponding text boxes in OCR data
              for i, text in enumerate(ocr_data['text']):
                  if match['text'] in text:
                      x = ocr_data['left'][i]
                      y = ocr_data['top'][i]
                      w = ocr_data['width'][i]
                      h = ocr_data['height'][i]
                      redaction_boxes.append((x, y, w, h))
          
          # Apply redactions
          img = apply_redaction(img, redaction_boxes)
          
          # Save redacted image
          cv2.imwrite(output_path, img)
          
          # Log redactions
          if ${if cfg.auditLog then "True" else "False"}:
              log_redaction(image_path, pii_matches)
          
          print(f"Redacted {len(pii_matches)} PII instance(s) in {image_path}")
          return True

      if __name__ == "__main__":
          image = os.environ.get('SCREENSHOT', sys.argv[1] if len(sys.argv) > 1 else None)
          output = os.environ.get('OUTPUT', sys.argv[2] if len(sys.argv) > 2 else image)
          
          success = redact_screenshot(image, output)
          sys.exit(0 if success else 1)
      PYTHON_EOF
      '')
    ];
  };
}
