---
name: forge-mesh-ops
description: "Manage forge mesh topology: provision nodes, promote master, demote nodes, and verify routing readiness."
metadata:
  short-description: Operate mesh topology
---

# Forge Mesh Ops

## Use This Skill When
- Bootstrapping node routing on a machine.
- Changing mesh master ownership.
- Verifying endpoint health before node/workflow routing.

## Required Inputs
- Node id(s).
- Endpoint values (`local` or SSH target).
- Master designation intent.

## Workflow

### 1) Inspect
- `forge mesh status`
- `forge mesh catalog`

### 2) Bootstrap Node
- `forge mesh provision <node-id>`
- Promote to master with endpoint:
  - `forge mesh promote <node-id> --endpoint <addr>`

### 3) Topology Updates
- Demote: `forge mesh demote <node-id>`
- Auth telemetry: `forge mesh report-auth <node-id> <profile-id> <ok|expired|missing>`

### 4) Routing Check
- `forge node ls`
- `forge node exec <node-id> -- true`

## Guardrails
- Keep exactly one intended master.
- Do not promote without endpoint for remote routing use.
- Re-check mesh status after each promote/demote.

## Output Contract
Always return:
1. Mesh status before/after.
2. Master node id + endpoint.
3. Routing verification command + result.
4. Any node still offline/missing endpoint.
