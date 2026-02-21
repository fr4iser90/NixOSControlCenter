# SSH Server Manager - Security

## Security Considerations

### Automatic SSH Config Management

- **Backup**: SSH config backed up before changes
- **Auto-Revert**: Automatically reverts to secure settings
- **Prevention**: Prevents permanent security weakening

### Audit Trail

- **Complete Tracking**: Request lifecycle tracking
- **Timestamps**: All actions timestamped
- **IP Logging**: Requester IP addresses logged
- **Approval/Denial Reasons**: Reasons recorded for compliance

### Access Controls

- **Request Validation**: Requests validated before processing
- **Status Checking**: Prevents duplicate processing
- **Auto-Cleanup**: Old requests automatically cleaned up

## Security Model

```
User Request → Validation → Storage → Notification → Admin Review → Decision → SSH Config Update → Auto-Disable
```

## Security Best Practices

1. **Use Request/Approval**: Prefer request/approval workflow over direct grant
2. **Review Promptly**: Review requests promptly to avoid blocking users
3. **Monitor Logs**: Regularly audit request logs for security issues
4. **Clean Up**: Regularly clean up old requests
5. **Notifications**: Configure notifications for security awareness
6. **Reasonable Durations**: Set reasonable maximum durations
7. **Audit Compliance**: Use audit logs for compliance requirements

## Security Configuration

```nix
{
  modules.security.ssh-server-manager = {
    enable = true;
    request-access = {
      defaultDuration = 300;  # 5 minutes (reasonable default)
      maxDuration = 3600;     # 1 hour (maximum)
    };
    grant-access = {
      defaultDuration = 300;  # 5 minutes
      maxDuration = 3600;     # 1 hour
    };
  };
}
```

## Threat Model

- **Unauthorized Access**: Request/approval workflow prevents unauthorized access
- **Permanent Weakness**: Auto-disable prevents permanent security weakening
- **Audit Compliance**: Complete audit trail for compliance
- **Notification Security**: Secure notification delivery
