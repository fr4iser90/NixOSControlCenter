{ pkgs, lib, cfg }:

with lib;

pkgs.writeShellScriptBin "encrypt-snapshot" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  INPUT_FILE=""
  OUTPUT_FILE=""
  METHOD="both"
  SOPS_KEYS=""
  AGE_KEY=""
  FIDO2_DEVICE=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input)
        INPUT_FILE="$2"
        shift 2
        ;;
      --method)
        METHOD="$2"
        shift 2
        ;;
      --sops-keys)
        SOPS_KEYS="$2"
        shift 2
        ;;
      --age-key)
        AGE_KEY="$2"
        shift 2
        ;;
      --fido2-device)
        FIDO2_DEVICE="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  
  if [ -z "$INPUT_FILE" ] || [ ! -f "$INPUT_FILE" ]; then
    echo "Error: --input file is required and must exist"
    exit 1
  fi
  
  OUTPUT_FILE="$INPUT_FILE.encrypted"
  
  # Determine encryption method
  USE_SOPS=false
  USE_FIDO2=false
  
  case "$METHOD" in
    sops)
      USE_SOPS=true
      ;;
    fido2)
      USE_FIDO2=true
      ;;
    both)
      USE_SOPS=true
      USE_FIDO2=true
      ;;
    *)
      echo "Error: Invalid method. Use 'sops', 'fido2', or 'both'"
      exit 1
      ;;
  esac
  
  # Encrypt with sops
  if [ "$USE_SOPS" = "true" ]; then
    echo "🔐 Encrypting with sops..."
    
    if ! command -v sops >/dev/null 2>&1; then
      echo "⚠️  sops not found, skipping sops encryption"
      USE_SOPS=false
    else
      # Create sops config if it doesn't exist
      SOPS_CONFIG="$HOME/.sops.yaml"
      if [ ! -f "$SOPS_CONFIG" ]; then
        cat > "$SOPS_CONFIG" <<EOF
creation_rules:
  - path_regex: .*\.encrypted$
    age: >-
      ${optionalString (cfg.encryption.sops.ageKeyFile != "") "AGE_KEY_FILE=${cfg.encryption.sops.ageKeyFile}"}
EOF
      fi
      
      # Set age key if provided
      if [ -n "$AGE_KEY" ] && [ -f "$AGE_KEY" ]; then
        export SOPS_AGE_KEY_FILE="$AGE_KEY"
      fi
      ${optionalString (cfg.encryption.sops.ageKeyFile != "") ''
      if [ -z "$SOPS_AGE_KEY_FILE" ] && [ -n "${cfg.encryption.sops.ageKeyFile}" ] && [ -f "${cfg.encryption.sops.ageKeyFile}" ]; then
        export SOPS_AGE_KEY_FILE="${cfg.encryption.sops.ageKeyFile}"
      fi
      ''}
      
      # Encrypt with sops
      if sops -e "$INPUT_FILE" > "$OUTPUT_FILE" 2>/dev/null; then
        echo "✅ Encrypted with sops"
        INPUT_FILE="$OUTPUT_FILE"  # Use encrypted file for next step if using both
      else
        echo "⚠️  sops encryption failed, continuing without sops"
        USE_SOPS=false
        OUTPUT_FILE="$INPUT_FILE.encrypted"
      fi
    fi
  fi
  
  # Encrypt with FIDO2 (using age-plugin-yubikey or similar)
  if [ "$USE_FIDO2" = "true" ]; then
    echo "🔐 Encrypting with FIDO2..."
    
    # Check for age-plugin-yubikey
    if command -v age-plugin-yubikey >/dev/null 2>&1; then
      # Generate age identity from FIDO2 device
      if [ -n "$FIDO2_DEVICE" ]; then
        DEVICE_ARG="--device $FIDO2_DEVICE"
      else
        DEVICE_ARG=""
      fi
      
      # Create age identity from YubiKey
      IDENTITY_FILE=$(mktemp)
      trap "rm -f $IDENTITY_FILE" EXIT
      
      if age-plugin-yubikey -i > "$IDENTITY_FILE" 2>/dev/null; then
        # Encrypt with age using YubiKey identity
        RECIPIENT=$(age-plugin-yubikey -r 2>/dev/null | head -1)
        if [ -n "$RECIPIENT" ]; then
          if age -r "$RECIPIENT" -o "$OUTPUT_FILE" "$INPUT_FILE" 2>/dev/null; then
            echo "✅ Encrypted with FIDO2/YubiKey"
          else
            echo "⚠️  FIDO2 encryption failed"
          fi
        else
          echo "⚠️  Could not get FIDO2 recipient"
        fi
      else
        echo "⚠️  Could not access FIDO2 device"
      fi
    elif command -v age >/dev/null 2>&1; then
      # Fallback: Use age with manual FIDO2 setup
      echo "⚠️  age-plugin-yubikey not found, FIDO2 encryption requires manual setup"
      echo "   Install age-plugin-yubikey for FIDO2 support"
    else
      echo "⚠️  age not found, skipping FIDO2 encryption"
    fi
  fi
  
  # If no encryption succeeded, create a simple encrypted archive as fallback
  if [ ! -f "$OUTPUT_FILE" ] || [ "$OUTPUT_FILE" = "$INPUT_FILE" ]; then
    echo "⚠️  No encryption method succeeded, using gpg as fallback..."
    if command -v gpg >/dev/null 2>&1; then
      # Try to encrypt with GPG (user's default key)
      if gpg --encrypt --armor --output "$OUTPUT_FILE" "$INPUT_FILE" 2>/dev/null; then
        echo "✅ Encrypted with GPG (fallback)"
      else
        echo "❌ All encryption methods failed"
        exit 1
      fi
    else
      echo "❌ No encryption tools available"
      exit 1
    fi
  fi
  
  echo "✅ Encryption complete: $OUTPUT_FILE"
''

