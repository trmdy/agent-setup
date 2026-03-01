---
name: forge-node-ops
description: Use forge node command family for remote command routing and per-node registry access.
metadata:
  short-description: Operate mesh nodes
---

# Forge Node Ops

## Use This Skill When
- Need remote command execution on a node.
- Need per-node registry list/show/update.
- Need deterministic check that root dispatch exposes `forge node`.

## Required Inputs
- Node id.
- Mesh master state.
- Command string for remote execution.

## Workflow

### 1) Preflight
- `forge node ls`
- Ensure target node exists and has endpoint.

### 2) Remote Command Exec
- `forge node exec <node-id> -- <command>`
- Example:
  - `forge node exec node-a -- forge registry ls agents`

### 3) Registry Passthrough
- `forge node registry ls <node-id> [agents|prompts]`
- `forge node registry show <node-id> <agent|prompt> <name>`
- `forge node registry update <node-id> <agent|prompt> <name> [flags]`

## Failure Triage
- `unknown forge command: node` => root CLI dispatch missing/old binary.
- `node <id> not found in mesh registry` => run `forge mesh provision`.
- `offline: endpoint missing` => set endpoint via `forge mesh promote --endpoint`.
- SSH exit `255` semantics => treat as offline transport failure.

## Output Contract
Always return:
1. Node id targeted.
2. Routed command.
3. Exit status and key stdout/stderr lines.
4. Next operator fix if routing failed.

