# Workspace lifecycle

Deterministic classification via CLI.

## Prefer

```bash
ncc ai workflow lifecycle --workspace ID --json
ncc ai workflow fleet --json
```

## States

| State | Meaning |
|-------|---------|
| `active` | Recent commits, dirty tree, doing tasks, or open PRs |
| `later` | Open todo tasks but quiet git (parked backlog) |
| `once` | Quiet, no open work — finished one-shot / reference |
| `archive-candidate` | Very old + no open work |

Do not archive remotes. Point to `workspace-archive-suggest` for a plan.
