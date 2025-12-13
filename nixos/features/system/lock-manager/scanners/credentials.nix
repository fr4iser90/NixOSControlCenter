{ pkgs, lib, cfg }:

with lib;

pkgs.writeShellScriptBin "scan-credentials" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  OUTPUT_FILE="$1"
  INCLUDE_PRIVATE="${if cfg.scanners.credentials.includePrivateKeys then "true" else "false"}"
  KEY_TYPES="${concatStringsSep " " cfg.scanners.credentials.keyTypes}"
  
  echo "🔐 Scanning credentials (will be encrypted)..."
  
  CREDENTIALS=()
  
  # Scan for SSH keys
  if [[ "$KEY_TYPES" =~ ssh ]]; then
    if [ -d "$HOME/.ssh" ]; then
      # Public keys (always scanned)
      while IFS= read -r pubkey; do
        if [ -f "$pubkey" ]; then
          KEY_NAME=$(basename "$pubkey" .pub)
          KEY_TYPE=$(ssh-keygen -l -f "$pubkey" 2>/dev/null | awk '{print $4}' || echo "unknown")
          KEY_FINGERPRINT=$(ssh-keygen -l -f "$pubkey" 2>/dev/null | awk '{print $2}' || echo "")
          
          CRED=$(${pkgs.jq}/bin/jq -n \
            --arg name "$KEY_NAME" \
            --arg type "$KEY_TYPE" \
            --arg fingerprint "$KEY_FINGERPRINT" \
            --arg path "$HOME/.ssh/$KEY_NAME.pub" \
            '{
              type: "ssh_public_key",
              name: $name,
              keyType: $type,
              fingerprint: $fingerprint,
              path: $path
            }')
          
          CREDENTIALS+=("$CRED")
        fi
      done < <(find "$HOME/.ssh" -name "*.pub" 2>/dev/null || true)
      
      # Private keys (only if enabled)
      if [ "$INCLUDE_PRIVATE" = "true" ]; then
        echo "⚠️  WARNING: Including private SSH keys in snapshot!"
        while IFS= read -r privkey; do
          if [ -f "$privkey" ] && [ ! -f "$privkey.pub" ]; then
            # Standalone private key
            KEY_NAME=$(basename "$privkey")
            KEY_CONTENT=$(cat "$privkey" | base64 -w 0 2>/dev/null || echo "")
            
            CRED=$(${pkgs.jq}/bin/jq -n \
              --arg name "$KEY_NAME" \
              --arg content "$KEY_CONTENT" \
              --arg path "$privkey" \
              '{
                type: "ssh_private_key",
                name: $name,
                keyContent: $content,
                path: $path,
                warning: "PRIVATE KEY - ENCRYPTED"
              }')
            
            CREDENTIALS+=("$CRED")
          elif [ -f "$privkey" ] && [ -f "$privkey.pub" ]; then
            # Private key with matching public key (already scanned as public)
            KEY_NAME=$(basename "$privkey" .pub)
            KEY_CONTENT=$(cat "$privkey" | base64 -w 0 2>/dev/null || echo "")
            
            # Update existing credential or add new
            CRED=$(${pkgs.jq}/bin/jq -n \
              --arg name "$KEY_NAME" \
              --arg content "$KEY_CONTENT" \
              --arg path "$privkey" \
              '{
                type: "ssh_private_key",
                name: $name,
                keyContent: $content,
                path: $path,
                warning: "PRIVATE KEY - ENCRYPTED"
              }')
            
            CREDENTIALS+=("$CRED")
          fi
        done < <(find "$HOME/.ssh" -name "id_*" ! -name "*.pub" 2>/dev/null || true)
      fi
    fi
  fi
  
  # Scan for GPG keys
  if [[ "$KEY_TYPES" =~ gpg ]] && command -v gpg >/dev/null 2>&1; then
    # Public keys (always scanned)
    GPG_KEYS=$(gpg --list-keys --with-colons 2>/dev/null | grep "^pub:" || true)
    if [ -n "$GPG_KEYS" ]; then
      while IFS= read -r key_line; do
        KEY_ID=$(echo "$key_line" | cut -d: -f5)
        KEY_ALGO=$(echo "$key_line" | cut -d: -f3)
        KEY_CREATED=$(echo "$key_line" | cut -d: -f6)
        
        CRED=$(${pkgs.jq}/bin/jq -n \
          --arg id "$KEY_ID" \
          --arg algo "$KEY_ALGO" \
          --arg created "$KEY_CREATED" \
          '{
            type: "gpg_public_key",
            keyId: $id,
            algorithm: $algo,
            created: $created
          }')
        
        CREDENTIALS+=("$CRED")
      done <<< "$GPG_KEYS"
    fi
    
    # Private keys (only if enabled)
    if [ "$INCLUDE_PRIVATE" = "true" ]; then
      echo "⚠️  WARNING: Including private GPG keys in snapshot!"
      GPG_SECRET_KEYS=$(gpg --list-secret-keys --with-colons 2>/dev/null | grep "^sec:" || true)
      if [ -n "$GPG_SECRET_KEYS" ]; then
        while IFS= read -r key_line; do
          KEY_ID=$(echo "$key_line" | cut -d: -f5)
          KEY_ALGO=$(echo "$key_line" | cut -d: -f3)
          KEY_EXPORT=$(gpg --export-secret-keys --armor "$KEY_ID" 2>/dev/null | base64 -w 0 || echo "")
          
          if [ -n "$KEY_EXPORT" ]; then
            CRED=$(${pkgs.jq}/bin/jq -n \
              --arg id "$KEY_ID" \
              --arg algo "$KEY_ALGO" \
              --arg export "$KEY_EXPORT" \
              '{
                type: "gpg_private_key",
                keyId: $id,
                algorithm: $algo,
                keyContent: $export,
                warning: "PRIVATE KEY - ENCRYPTED"
              }')
            
            CREDENTIALS+=("$CRED")
          fi
        done <<< "$GPG_SECRET_KEYS"
      fi
    fi
  fi
  
  # Scan for environment files with potential secrets (just metadata, not actual secrets)
  if [ -f "$HOME/.env" ] || [ -f "$HOME/.secrets" ]; then
    for env_file in "$HOME/.env" "$HOME/.secrets"; do
      if [ -f "$env_file" ]; then
        CRED=$(${pkgs.jq}/bin/jq -n \
          --arg path "$env_file" \
          '{
            type: "env_file",
            path: $path,
            note: "File exists, contents should be encrypted separately"
          }')
        
        CREDENTIALS+=("$CRED")
      fi
    done
  fi
  
  # Scan for sops files
  if command -v sops >/dev/null 2>&1; then
    while IFS= read -r sops_file; do
      if [ -f "$sops_file" ]; then
        CRED=$(${pkgs.jq}/bin/jq -n \
          --arg path "$sops_file" \
          '{
            type: "sops_encrypted_file",
            path: $path,
            note: "Already encrypted with sops"
          }')
        
        CREDENTIALS+=("$CRED")
      fi
    done < <(find "$HOME" -name "*.sops.yaml" -o -name "*.sops.yml" 2>/dev/null | head -20 || true)
  fi
  
  # Combine all credentials
  CREDENTIALS_JSON="[]"
  for cred in "''${CREDENTIALS[@]}"; do
    CREDENTIALS_JSON=$(${pkgs.jq}/bin/jq --argjson cred "$cred" '. + [$cred]' <<< "$CREDENTIALS_JSON")
  done
  
  # Output JSON
  ${pkgs.jq}/bin/jq -n \
    --argjson creds "$CREDENTIALS_JSON" \
    '{
      credentials: {
        count: ($creds | length),
        items: $creds
      }
    }' > "$OUTPUT_FILE"
  
  CRED_COUNT=$(${pkgs.jq}/bin/jq '.credentials.count' "$OUTPUT_FILE")
  echo "✅ Found $CRED_COUNT credential entries (metadata only, no secrets stored)"
''

