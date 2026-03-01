---
name: forge-workflow-operator
description: Create and run forge workflows with validation gates, human approvals, logs, and resumable run handling.
metadata:
  short-description: Operate forge workflows
---

# Forge Workflow Operator

## Use This Skill When
- Need workflow bootstrap in a repo.
- Need deterministic smoke checks for workflow engine.
- Need human approval flow (`approve` / `deny`).
- Need node-routed workflow execution.

## Hard Limits
- Runtime supports `bash` and `human` steps only.
- `agent`, `loop`, `job`, `workflow`, `logic` may parse/validate, but not execute.

## Required Inputs
- Repo path (`--chdir` or current dir).
- Workflow name.
- Optional node id for remote run.
- Approval decision policy for human-gated steps.

## Workflow

### 1) Author
- Put workflow in `.forge/workflows/<name>.toml`.
- Minimal runnable:
```toml
name = "smoke"

[[steps]]
id = "s1"
type = "bash"
cmd = "echo hello"
```

### 2) Validate
- `forge workflow ls`
- `forge workflow validate <name>`
- Block run on validation error.

### 3) Run
- Local: `forge workflow run <name> --json`
- Via node: `forge workflow run <name> --node <node-id> --json`

### 4) Observe
- `forge workflow logs <run-id>`
- `forge workflow blocked <run-id>`

### 5) Human Gate
- Approve: `forge workflow approve <run-id> --step <step-id>`
- Deny: `forge workflow deny <run-id> --step <step-id> --reason "<text>"`

## Output Contract
Always return:
1. Workflow file path used.
2. Run id(s).
3. Final run status (`success|running|failed|canceled`).
4. Next operator action (approve/deny/fix/re-run).

