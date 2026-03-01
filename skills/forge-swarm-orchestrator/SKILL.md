---
name: forge-swarm-orchestrator
description: Orchestrate forge loop swarms with sv task flow, staged ramp-up, health checks, strict parity gates, and safe wind-down. Use for launch/debug/scale of multi-agent development loops.
metadata:
  short-description: Run and control forge swarms
---

# Forge Swarm Orchestrator

## Use This Skill When
- Spinning up new forge loop swarms.
- Loops look alive but do no real work.
- Scaling from 1 loop to many loops safely.
- Enforcing parity quality gates before task closure.
- Shutting down swarms without losing task state.

## Required Inputs
- Target `sv` project id(s).
- Prompt file(s) per role.
- Harness/profile map (Codex/Claude).
- Concurrency limits per harness.
- Stop conditions (max iterations, task-count threshold, or manual hold).
- Branch policy: never push to `main` from agents.
- Task-picking policy: default `open/ready` first, explicit `in_progress` ownership rules.
- Runner ownership policy: `daemon` required for swarm loops.
- Quant-stop command path (recommended): `.../forge/scripts/swarm-quant-stop.sh`.

## Daemon Ownership Policy (hard gate)
- Always spawn loops with `--spawn-owner daemon`.
- Never rely on implicit default owner.
- Treat `runner_owner=local` as failed spawn for swarm use.
- Block ramp-up unless proof loop shows:
  - `runner_owner=daemon`
  - `runner_pid_alive=true`
  - `runner_daemon_alive=true`
- If spawned as local by mistake: stop/kill and respawn as daemon.

## Topology Selection
The `dev + design + review + stale + committer` topology is one option for large repos.
Choose smaller topology by scope:
- Small scope (single feature or bugfix): `1-3` dev loops only. Add review loop only near merge.
- Medium scope (few parallel tracks): `3-6` dev loops + `1` review/design shared loop.
- Large scope (many active tasks, parity work): full role split:
  - dev loops,
  - design parity loop,
  - code review loop,
  - stale in-progress auditor,
  - committer loop.
- Always start smallest that can keep flow, then scale up only when backlog/throughput justify it.

## Workflow

### Task Selection Policy (default)
- Default pick path: highest-priority `open/ready` task.
- Do not dogpile on random `in_progress` tasks.
- Allow `in_progress` pickup only when:
  - same agent ownership (already working it), or
  - stale takeover after a clear timeout (recommended `>=45m` no update).
- Require explicit claim message on pickup (for example `fmail send task "claim: <id> by <agent>"`).
- If `sv task start <id>` fails due to race/already-started, select a different `open` task.
- Skip container tasks (epics/meta tasks); pick actionable leaf tasks.

### 1) Preflight
- Verify CLI and integration: `forge --robot-help`, `sv --robot-help`, `sv task --robot-help`.
- Verify spawn args available in this forge build: `forge up --help`.
- Snapshot task backlog: `sv task count --project <PROJECT_ID> --status open` and `in_progress`.
- Confirm prompts are self-contained; no unresolved "use base behavior" references.
- Confirm branch/push guardrail in prompt: no direct push to `main`; no branch create/switch unless explicitly allowed.
- Confirm prompt encodes anti-dogpile task selection policy.
- Confirm prompt strategy works in this environment:
  - preferred: `--prompt <prompt-name>`
  - fallback: `--prompt-msg "$(cat <prompt-file>)"`

### 2) Single-Loop Proof (required)
- Start exactly one real loop with real prompt and full runtime args.
- Must include: `--spawn-owner daemon`.
- Force quick validation run first (`--max-iterations 1`).
- Validate ownership gate immediately after spawn:
  - `forge ps --json | jq ... runner_owner/runner_pid_alive/runner_daemon_alive`
- Inspect logs; require evidence of meaningful work:
  - task selection,
  - file read/edit,
  - tests/lint/typecheck where relevant,
  - task/status update.
- If loop exits idle/early, fix root cause before scaling.

### 3) Controlled Ramp-Up
- Scale in small steps: `1 -> 2/3 -> role mix -> full swarm`.
- Add review/design/commit loops only after dev loops show sustained throughput.
- Keep commit loop isolated and cadence-based.
- Respect per-harness concurrency caps; avoid pool starvation.
- Every ramp stage must preserve daemon ownership checks.

### 4) Active Operations
- Re-check every 10-20 minutes:
  - loop health/status,
  - owner health (`runner_owner`, `runner_pid_alive`, `runner_daemon_alive`),
  - last-log activity,
  - `sv` flow (`open -> in_progress -> closed`),
  - stale `in_progress` tasks.
- Require agent comms via `fmail` where collaboration matters.
- Reassign or reopen stale tasks immediately.
- Detect and correct dogpile early (many loops reporting same task while other `open` tasks exist).

### 5) Quality Gates
- UI parity tasks: require DPC target and visual/manual verification.
- Functionality tasks: require behavior parity and regression checks.
- Data parity tasks: block closure if tenant datasets diverge.
- No "close on near-miss".

### 6) Wind-Down
- Stop loops by tag/project.
- Confirm loops reached stopped state.
- Sync task/project state.
- Summarize:
  - completed,
  - blocked,
  - stale/reopened,
  - next spawn set.

## Output Contract
When this skill is used, always produce:
1. Spawn command set (ordered by ramp stage).
2. Health-check command set.
3. Stop/wind-down command set.
4. Explicit stop criteria.
5. Daemon-ownership verification commands and expected output pattern.

## References
- Command templates: `references/commands.md`
- Failure diagnosis and fixes: `references/failure-playbook.md`
