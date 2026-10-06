# Workspace audit

Deterministic gap scan for one registered NCC workspace.

## Rules

- Prefer `ncc ai workflow audit --workspace <id> --json` over inventing file lists.
- Gaps are enums only (agents-md, skills, impressum, privacy, roadmap-doc, license, precommit, githooks, readme).
- Suggested templates use English ids (`privacy-policy-creator`, …).
- For autonomous writes: template `autonomous-agent-run`.
- Never invent legal / tax registration numbers.
- If user asks to create tasks: `ncc ai workflow plan --workspace <id>`.

## Output

1. Missing gaps (bullet list)
2. Suggested template ids
3. Optional: plan result (created task ids)
