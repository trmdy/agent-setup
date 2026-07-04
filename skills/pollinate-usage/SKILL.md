---
name: pollinate-usage
description: Configure and operate Pollinate, the standalone trigger substrate for schedules, event polls, webhooks, temporary hooks, routers, delivery policies, context resolution, job inspection, and typed actions into Honeybee, Hermes, HTTP, shell commands, or internal emits. Use when Codex needs durable time/event/webhook activation, GitHub PR routing to hive agents, debounced/batched/throttled delivery, or observable trigger-to-action automation.
---

# Pollinate Usage

Pollinate owns when work fires. It does not reason and does not run agents in-process; it resolves triggers, delivery policy, context, and actions, then shells out or calls targets such as `hive`.

## Workflow

1. Inspect the store and daemon:

```sh
pollinate --help
pol status
pol list
pol jobs --last 20
pol ledger -n 50
pol daemon status
```

2. Choose the source:

- `manual`: fire only with `pol trigger`.
- `schedule`: `--every`, `--cron`, or `--once`.
- `poll`: command/http/file polling with persisted cursor.
- `webhook`: local HTTP `/hook/<path>`, optional HMAC secret and transform.

3. Choose delivery:

- `immediate`: one activation becomes one job.
- `throttled`: fire, then cooldown; optional collection.
- `batched`: collect for a window or until max batch.
- `debounced`: fire after quiet period.

4. Choose action:

- `command`, `http`, `emit`, `hermes`.
- `honeybee-flow`, `honeybee-loop`, `honeybee-spawn`, `honeybee-send`, `honeybee-buz`, `honeybee-kill`.
- `sequence` via `--action-json` for serial or parallel action orchestration.

5. Dry-run before enabling external effects:

```sh
pol trigger my-trigger --payload '{"sample":true}' --dry-run
pol hook test my-webhook --payload '{"action":"opened"}'
```

Read [references/pollinate-triggers.md](references/pollinate-triggers.md) for trigger syntax and [references/pollinate-actions.md](references/pollinate-actions.md) for action/router patterns.

## Store And Config

`POLLINATE_STORE_ROOT` defaults to `~/.pollinate`. Important paths:

- `triggers/<id>.toml`
- `router-plugins/<name>.mjs`
- `state/schedule-state.json`
- `state/delivery-state.json`
- `state/cursors.json`
- `state/router-bindings/...`
- `jobs/<jobId>.json`
- `ledger.jsonl`

Configure command execution explicitly with `[execution]` so daemon jobs can find `hive`, `gh`, `node`, and project tools without relying on interactive shell startup.

## Common Examples

```sh
pol create hourly-hive-audit --source schedule --every 1h \
  --cwd "$PWD" --action honeybee-flow --flow audit-flow --arg target=src

pol create todo-poll --source poll --poll-interval 30s --fetch-file ./TODO.md \
  --cursor hash --emit per-poll --delivery debounced --quiet-period 2m \
  --action honeybee-loop --loop bee=codex --loop context=ralph --loop prompt='Work the next TODO item.'

pol hook create callback --ttl 15m --once --action emit --subject callback.received

pol github create-pr-router repo-pr-router --repo Owner/repo --cwd "$PWD" \
  --secret env:GITHUB_WEBHOOK_SECRET --base-url https://hooks.example.com --install-webhook
```

## Safety Rules

- Keep Pollinate dumb: encode when to fire and how to deliver, not strategic judgment.
- Always set `cwd` for command-backed Honeybee/Hermes work.
- Prefer `env:NAME` secrets in trigger files; do not hard-code webhook/shared secrets.
- Use `--dry-run`, `hook test`, or `--install-webhook --dry-run` before provider-facing changes.
- Set `maxConcurrent` intentionally; default flag path is 1.
- Use `batched` or `debounced` for noisy webhook/comment streams.
- Use router triggers when many events must correlate to one long-lived target.
- Treat delivery as at-least-once. Retries, webhook redelivery, and overlapping schedules can fire the same activation twice, so actions that spawn or mutate (`honeybee-spawn`/`-flow`/`-send`) must be idempotent or dedupe on a stable key (event id, shard id, PR number). Prefer `debounced`/`throttled` for bursty sources, cap `maxConcurrent`, and make the downstream flow/loop check "already handled?" before doing work — otherwise one noisy webhook becomes a swarm of duplicate bees.
- Watch `pol jobs`, `pol job <id>`, and `pol ledger` after changes.

## Output Contract

When using this skill, report the trigger id, source, delivery policy, action target, context variables, dry-run result or validation command, daemon expectation, and job/ledger inspection commands.
