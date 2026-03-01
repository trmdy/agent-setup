---
name: forge-team-task-ops
description: "Operate forge teams and task inbox flow: team bootstrap, member management, assignment, retries, and queue visibility."
metadata:
  short-description: Operate team/task inbox
---

# Forge Team Task Ops

## Use This Skill When
- Need new team setup for delegation/workflows.
- Need queue visibility by team.
- Need task lifecycle handling (`send`, `assign`, `retry`).

## Required Inputs
- Team id or name.
- Agent ids for membership/assignment.
- Task payload: `type`, `title`, optional `body/repo/tags/external-id`.
- Priority policy.

## Workflow

### 1) Team Bootstrap
- `forge team new <team-name> --default-assignee <agent-id>`
- `forge team member add <team-name> <agent-id> --role leader`
- `forge team member ls <team-name>`
- `forge team show <team-name>`

### 2) Queue Intake
- `forge --json task send --team <team> --type <type> --title "<title>" [--body "..."] [--priority <n>]`
- `forge task ls --team <team>`
- `forge task show <task-id>`

### 3) Assignment + Execution
- `forge task assign <task-id> --agent <agent-id> [--actor <agent-id>]`
- Reassign via same command to another assignee.

### 4) Retry Path
- `forge task retry <task-id> [--actor <agent-id>]`

## Guardrails
- Always check member exists before assign.
- Always capture `task-id` from `task send` response.
- For machine output, pass global `--json` before command family.

## Output Contract
Always return:
1. Team id and member list used.
2. Task ids created/updated.
3. Queue summary (`queued/assigned/running/blocked/open`).
4. Remaining blocker if queue not draining.
