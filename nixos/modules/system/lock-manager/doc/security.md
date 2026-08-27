# Lock Manager - Security

## Security Considerations

### Metadata-Only Credential Scanning

- **Default Behavior**: Only metadata is stored (fingerprints, key IDs)
- **No Private Keys**: Private keys are NOT stored by default
- **Security Rationale**: Defense in depth, risk minimization
- **Restoration**: Cannot restore private keys, but can identify which keys need restoration

### Encryption

- **Required**: All snapshots should be encrypted
- **Methods**: Supports sops-nix and FIDO2/YubiKey
- **Storage**: Encrypted snapshots safe for Git storage
- **Key Management**: Store encryption keys separately from snapshots

### GitHub Upload

- **Private Repositories**: Use private repositories only
- **Encryption**: Even private repos should use encrypted snapshots
- **Token Security**: Use sops-nix for GitHub token encryption
- **Access Control**: Limit repository access

## Security Model

```
System State → Scanners (Metadata Only) → Snapshot → Encryption → Storage
```

## Security Best Practices

1. **Use Encryption**: Always enable encryption for snapshots
2. **Metadata Only**: Keep credential scanning to metadata only (default)
3. **Separate Keys**: Store encryption keys separately from snapshots
4. **FIDO2**: Use FIDO2/YubiKey for additional security
5. **Verify Integrity**: Regularly verify snapshot integrity
6. **Key Rotation**: Rotate encryption keys periodically
7. **Access Control**: Limit access to snapshots and keys

## Security Configuration

```nix
{
  enable = true;
  encryption = {
    enable = true;
    method = "both";  # sops + FIDO2 for maximum security
    sops = {
      ageKeyFile = "/path/to/age-key.txt";
    };
    fido2 = {
      device = "/dev/hidraw0";
    };
  };
  scanners = {
    credentials = {
      includePrivateKeys = false;  # Default: metadata only
    };
  };
}
```

## Threat Model

- **Data Exposure**: Encryption prevents data exposure
- **Key Compromise**: Separate key storage limits impact
- **Metadata Leakage**: Metadata-only scanning minimizes risk
- **GitHub Security**: Private repos + encryption for GitHub uploads
