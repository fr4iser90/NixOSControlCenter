# Remote Assist Manager - Security

## Security Considerations

### Least privilege by default

- Sessions start in **view** unless explicitly configured otherwise
- Presence on the stream must not imply input rights
- Mode escalation (`view` → `assist` / `gated`) requires explicit host action

### Host always wins

- Freeze, input-off, deny, and end must work on the host’s local control path
- Guest must not be able to block overlay controls (focus steal, fullscreen traps)
- When in doubt, fail closed: drop guest input

### Invites and join auth

- Invite tokens are secret, single-use or short-TTL, and must not appear in the shared framebuffer if avoidable
- Expired/revoked invites must not reconnect mid-session without a new host grant
- Prefer binding a session to one guest identity for the session lifetime

### Gated input integrity

- Pending actions are snapshots of intent (target, event class, payload summary)
- Approval applies that pending item once; no silent “approve all forever” unless host opts in
- Timeouts on pending items discard rather than auto-apply
- Terminal and clipboard classes are high risk — default to approve or deny, never silent allow in `gated`

### Audit trail

- Log: session start/end, guest join/leave, mode changes, freeze/input toggles, approve/deny with reason codes
- Timestamps and session IDs required for post-incident review
- Do not log raw secrets from guest keystrokes (redact or hash payloads where feasible)

## Security Model

```
Invite (secret, TTL)
  → Join (authenticated guest)
  → Session mode (view | assist | gated)
  → Input path:
       view   → drop
       assist → apply unless frozen/disabled
       gated  → policy → queue → host decision → apply|drop
  → Audit
  → Auto-end on maxDuration / host end
```

## Threat Model

| Threat | Mitigation |
|--------|------------|
| Guest gains control without consent | Default `view`; separate input channel; explicit mode raise |
| Guest keeps control after help is done | Host end, input-off, freeze; session maxDuration |
| Malicious clicks while host looks away | `gated` + overlay queue; freeze hotkey |
| Invite link leaked / replayed | Short TTL, revoke, single redeem; rotate on leak |
| Overlay blocked / unusable | Privileged host UI path; fail closed on input |
| Clipboard exfil / inject | Deny or approve clipboard class; no auto sync in view |
| Keystroke logging of secrets in audit | Redact sensitive payloads; summarize event class |
| Privilege confusion (guest cursor looks like host) | Dual-cursor styling; clear host-owned system pointer |

## Security Best Practices

1. Use **view** for “look at my screen”; escalate only when needed
2. Use **gated** for terminals, file managers, browsers with sessions, and package tools
3. Keep sessions short; do not leave `assist` overnight
4. Confirm guest identity before raising mode
5. Prefer freeze over trusting verbal “I stopped”
6. Review audit after any `assist` / `gated` session that touched credentials or system config
7. Never display invite secrets on the shared screen

## Security Configuration (target)

```nix
{
  modules.security.remote-assist-manager = {
    enable = true;
    defaultMode = "view";
    session = {
      maxDuration = 1800;  # 30 minutes
      inviteTtl = 300;     # 5 minutes
    };
    policy = {
      "terminal.input" = "approve";
      "keyboard.chord" = "approve";
      "clipboard" = "deny";
      "file.drop" = "approve";
      "pointer.click" = "approve";
    };
    audit = {
      enable = true;
      redactKeyPayloads = true;
    };
  };
}
```

## Residual Risks

- Compositor/input-injection bugs can bypass intended gates — treat assist as trusted-guest only
- Screen content itself leaks secrets (passwords on screen, notifications); host must scrub UI before share
- Network transport choice affects confidentiality; use encrypted channels only when implemented

See [ARCHITECTURE.md](./ARCHITECTURE.md) for mode and policy design.
