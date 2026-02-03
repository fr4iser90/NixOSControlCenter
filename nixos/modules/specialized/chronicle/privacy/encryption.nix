{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.privacy.encryption;
in
{
  options.services.chronicle.privacy.encryption = {
    enable = mkEnableOption "encryption for step recorder data";

    method = mkOption {
      type = types.enum [ "gpg" "age" "aes256" ];
      default = "age";
      description = "Encryption method to use";
    };

    keyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to encryption key file";
    };

    recipient = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "GPG recipient or age public key";
    };

    encryptScreenshots = mkOption {
      type = types.bool;
      default = true;
      description = "Encrypt individual screenshots";
    };

    encryptSessions = mkOption {
      type = types.bool;
      default = true;
      description = "Encrypt session files";
    };

    encryptExports = mkOption {
      type = types.bool;
      default = true;
      description = "Encrypt export packages";
    };

    compressionLevel = mkOption {
      type = types.ints.between 0 9;
      default = 6;
      description = "Compression level before encryption (0-9)";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gnupg
      age
      openssl
      (pkgs.writeShellScriptBin "chronicle-encrypt" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Encryption Script for Step Recorder
      # Supports GPG, age, and AES-256 encryption

      INPUT_FILE="$1"
      OUTPUT_FILE="''${2:-$INPUT_FILE.enc}"
      METHOD="${cfg.method}"
      KEY_FILE="${toString cfg.keyFile}"
      RECIPIENT="${toString cfg.recipient}"
      COMPRESSION="${toString cfg.compressionLevel}"

      encrypt_with_gpg() {
          local input="$1"
          local output="$2"
          
          if [ -n "$RECIPIENT" ]; then
              ${pkgs.gnupg}/bin/gpg \
                  --encrypt \
                  --recipient "$RECIPIENT" \
                  --output "$output" \
                  --trust-model always \
                  --compress-level "$COMPRESSION" \
                  "$input"
          else
              echo "Error: GPG recipient not specified" >&2
              return 1
          fi
      }

      encrypt_with_age() {
          local input="$1"
          local output="$2"
          
          if [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ]; then
              ${pkgs.age}/bin/age \
                  --encrypt \
                  --recipients-file "$KEY_FILE" \
                  --output "$output" \
                  "$input"
          elif [ -n "$RECIPIENT" ]; then
              ${pkgs.age}/bin/age \
                  --encrypt \
                  --recipient "$RECIPIENT" \
                  --output "$output" \
                  "$input"
          else
              echo "Error: age key file or recipient not specified" >&2
              return 1
          fi
      }

      encrypt_with_aes256() {
          local input="$1"
          local output="$2"
          
          if [ -z "$KEY_FILE" ] || [ ! -f "$KEY_FILE" ]; then
              echo "Error: AES key file not specified or not found" >&2
              return 1
          fi
          
          # Read key from file
          local key=$(cat "$KEY_FILE")
          
          # Compress then encrypt
          ${pkgs.gzip}/bin/gzip -c -"$COMPRESSION" "$input" | \
          ${pkgs.openssl}/bin/openssl enc -aes-256-cbc \
              -salt \
              -pbkdf2 \
              -iter 100000 \
              -pass "pass:$key" \
              -out "$output"
      }

      # Main encryption logic
      case "$METHOD" in
          gpg)
              encrypt_with_gpg "$INPUT_FILE" "$OUTPUT_FILE"
              ;;
          age)
              encrypt_with_age "$INPUT_FILE" "$OUTPUT_FILE"
              ;;
          aes256)
              encrypt_with_aes256 "$INPUT_FILE" "$OUTPUT_FILE"
              ;;
          *)
              echo "Error: Unknown encryption method: $METHOD" >&2
              exit 1
              ;;
      esac

      echo "Encrypted: $INPUT_FILE -> $OUTPUT_FILE (method: $METHOD)"
      '')
      (pkgs.writeShellScriptBin "chronicle-decrypt" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Decryption Script for Step Recorder

      INPUT_FILE="$1"
      OUTPUT_FILE="''${2:-''${INPUT_FILE%.enc}}"
      METHOD="${cfg.method}"
      KEY_FILE="${toString cfg.keyFile}"

      decrypt_with_gpg() {
          local input="$1"
          local output="$2"
          
          ${pkgs.gnupg}/bin/gpg \
              --decrypt \
              --output "$output" \
              "$input"
      }

      decrypt_with_age() {
          local input="$1"
          local output="$2"
          
          if [ -z "$KEY_FILE" ] || [ ! -f "$KEY_FILE" ]; then
              echo "Error: age key file not specified or not found" >&2
              return 1
          fi
          
          ${pkgs.age}/bin/age \
              --decrypt \
              --identity "$KEY_FILE" \
              --output "$output" \
              "$input"
      }

      decrypt_with_aes256() {
          local input="$1"
          local output="$2"
          
          if [ -z "$KEY_FILE" ] || [ ! -f "$KEY_FILE" ]; then
              echo "Error: AES key file not specified or not found" >&2
              return 1
          fi
          
          local key=$(cat "$KEY_FILE")
          
          ${pkgs.openssl}/bin/openssl enc -aes-256-cbc \
              -d \
              -pbkdf2 \
              -iter 100000 \
              -pass "pass:$key" \
              -in "$input" | \
          ${pkgs.gzip}/bin/gunzip > "$output"
      }

      # Main decryption logic
      case "$METHOD" in
          gpg)
              decrypt_with_gpg "$INPUT_FILE" "$OUTPUT_FILE"
              ;;
          age)
              decrypt_with_age "$INPUT_FILE" "$OUTPUT_FILE"
              ;;
          aes256)
              decrypt_with_aes256 "$INPUT_FILE" "$OUTPUT_FILE"
              ;;
          *)
              echo "Error: Unknown encryption method: $METHOD" >&2
              exit 1
              ;;
      esac

      echo "Decrypted: $INPUT_FILE -> $OUTPUT_FILE"
      '')
      (pkgs.writeShellScriptBin "chronicle-generate-key" ''
      #!/usr/bin/env bash
      set -euo pipefail

      METHOD="${cfg.method}"
      KEY_DIR="$HOME/.config/chronicle/keys"
      mkdir -p "$KEY_DIR"

      case "$METHOD" in
          gpg)
              echo "Generating GPG key pair..."
              ${pkgs.gnupg}/bin/gpg --full-generate-key
              ;;
          age)
              KEY_FILE="$KEY_DIR/age-key.txt"
              echo "Generating age key pair..."
              ${pkgs.age}/bin/age-keygen -o "$KEY_FILE"
              echo "Key saved to: $KEY_FILE"
              echo "Public key:"
              grep "public key:" "$KEY_FILE"
              ;;
          aes256)
              KEY_FILE="$KEY_DIR/aes-key.txt"
              echo "Generating AES-256 key..."
              ${pkgs.openssl}/bin/openssl rand -base64 32 > "$KEY_FILE"
              chmod 600 "$KEY_FILE"
              echo "Key saved to: $KEY_FILE"
              ;;
      esac
      '')
    ];
  };
}
