# SSH Manager

One module for SSH on this host and optional outbound client tools.

```nix
{
  enable = true;            # sshd + unlock/lockdown (this host)
  client.enable = false;    # ncc ssh client (outbound) — default off
  workflow.enable = false;  # request/approve/monitor — optional
  passwordAuthentication = true;  # bootstrap-safe; then: ncc ssh lockdown
}
```

## Roles

| Flag | Meaning |
|------|---------|
| `enable` | OpenSSH daemon + temp-open / grant-access / status / lockdown |
| `client.enable` | Connection manager UI/CLI (`ncc ssh client`) |
| `workflow.enable` | Request/approve workflow (only with `enable`) |

## Anti-lockout

Daemon stays on while `enable = true`. Password auth defaults **on**; after keys work run `sudo ncc ssh lockdown`.

If OpenSSH is on and `network.services.ssh` is unset, port 22 is opened publicly (VPS-safe).

## Presets

| | Desktop | Server |
|--|---------|--------|
| `enable` | false | true |
| `client.enable` | false | false |

## Related

- Network module — firewall exposure
- User module — accounts / keys

Former names: `ssh-manager`, `ssh-manager` (merged here).
