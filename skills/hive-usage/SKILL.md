---
name: hive-usage
description: Operate Honeybee through the `hive` CLI for durable AI agent sessions, swarms, colonies, frames, flows, loops, buz messaging, sealing, transcripts, search, cleanup, remote nodes, and daemon state. Use when Codex must spawn or control Claude/Codex/OpenCode/Grok/Pi/Droid/arbitrary harness agents, coordinate multiple agents, inspect agent output, register reusable swarm blueprints, run Honeybee flows, or recover/stop Honeybee work.
---

# Hive Usage

Honeybee is the durable interactive agent control plane; its CLI is `hive`. Use it for process/session control, addressing, state, messaging, transcripts, handoffs, and mechanical flow/loop execution. Keep strategic decomposition in the calling agent or higher orchestrator.

Hive does not replace the native harness. It gives durable access to the harness process, so prompted bees can still use native harness features such as slash commands, built-in goal modes, built-in loops, tool modes, model switches, and any other harness-specific capability. Treat these as pass-through harness features: use them when useful, but verify the target bee kind actually supports the feature.

## Workflow

1. Check availability and state before acting:

```sh
hive --help
hive ps --wide
hive daemon status --json
hive node list
```

2. Choose the smallest primitive that fits:

- `hive run`: one-shot spawn, prompt, optional wait.
- `hive x`: fire-and-forget single bee.
- `hive spawn --count`: homogeneous swarm.
- `hive spawn --frame`: differentiated swarm from a saved frame.
- `hive flow run`: deterministic saved or ad-hoc orchestration.
- `hive loop start`: repeated work until a mechanical stop condition.

3. Address bees with stable selectors:

```sh
hive send CO.a3f "Continue with the next isolated task."
hive send @deep-review-001 "Report status and next blocker."
hive send colony:honeybee "Pause. Seal your current findings."
```

4. Require an output contract for non-trivial work. Prefer a seal when the downstream step must consume structured results:

```sh
hive wait CO.a3f --seal
hive last CO.a3f --seal
hive seals find "regression" --colony honeybee
```

5. Inspect and wind down explicitly:

```sh
hive tail CO.a3f -n 120
hive transcript CO.a3f --json
hive wait CO.a3f --last
hive kill CO.a3f
hive clean --dead --older-than 7d --dry-run
```

## Command Map

- Spawn/control: `spawn`, `run`, `x`, `send`, `brief`, `wait`, `tail`, `transcript`, `last`, `attach`, `kill`, `clean`.
- Organization: `colony`, `swarm`, `frame`, selectors `<bee-id>`, `@swarm`, `colony:name`.
- Orchestration: `flow define/run/runs/logs/status/cancel`, `loop start/status/logs/stop/list`.
- Messaging: `buz send/inbox/outbox/queue/read/purge/config`.
- Retrieval: `seal`, `seals find`, `search`.
- Infrastructure: `node`, `substrate`, `daemon`, `config`, `completion`.

Read [references/hive-commands.md](references/hive-commands.md) for detailed command syntax and [references/hive-patterns.md](references/hive-patterns.md) for operational patterns.

## Safety Rules

- Start with one bee or a tiny swarm, prove readiness and output shape, then scale.
- Treat `blocked`, `node_unreachable`, `kill_failed`, and readiness timeouts as hard operational signals. Inspect before retrying.
- Use `--yolo` deliberately. Claude defaults to permissionless; use `--no-yolo` when approvals matter.
- Use `--no-wait` only when an upper layer will check readiness later.
- Prefer `--background` flow runs and loops for durable async work; always record the run id.
- Do not search transcripts with `hive search`; it searches seals, ledger, and session records only.
- Clean dead metadata with `hive clean --dead --dry-run` before destructive cleanup.

## Common Examples

```sh
hive run codex -p "Inspect this repo and seal a risk summary." --cwd "$PWD" --wait --last
hive spawn codex --count 8 --cwd "$PWD" --colony audit --swarm-id audit-pass-001
hive send @audit-pass-001 "Each take a different module. Seal findings as JSON."
hive wait CO.a3f --seal
hive flow run deep-review --arg target=src --background
hive loop start --bee codex --cwd "$PWD" --context rolling --max 50 --prompt-file ./loop-task.md
```

## Output Contract

When using this skill, report the selected primitive, exact commands run or recommended, selectors/run ids created, how output will be collected, and the stop/cleanup command.
