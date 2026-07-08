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
hive retire CO.a3f                       # everyday stop: archive the record, keep it revivable
hive kill CO.a3f --yes                   # RARE: purge record + seals + run dir (not revivable)
hive clean --dead --older-than 7d --dry-run
```

## Command Map

- Spawn/control: `spawn`, `run`, `x`, `send`, `brief`, `wait`, `tail`, `transcript`, `last`, `attach`, `retire`/`archive` (everyday stop), `kill` (rare purge, `--yes`), `revive` (`--crashed`/`--all`/`--fresh`), `clean`.
- Organization: `colony`, `swarm`, `frame`, selectors `<bee-id>`, `@swarm`, `colony:name`, `spawned-by:<bee>` (children a bee spawned).
- Fleet/lineage: `fleet [<bee>]` — an orchestrator's spawned-child tree with each child's live state (running/blocked/sealed/dead), idle time, and last seal; defaults to self inside a bee, `--json` for the reconcile payload. Spawning a child through hive from inside a bee records the parent edge automatically, so the tree is always reconstructable from disk (never from the orchestrator's context).
- Orchestration: `flow define/run/runs/logs/status/cancel`, `loop start/status/logs/stop/list`.
- Messaging: `buz send/inbox/outbox/queue/read/purge/config`.
- Retrieval: `seal`, `seals find`, `search`.
- Cost/usage: `spend ingest`, `spend usage`, `spend session <bee>`, `spend report`, `spend leverage` — API-equivalent cost ledger over harness transcripts; `spend session` drills one bee down to cost, model mix, caching health, and a context-per-turn trajectory.
- Infrastructure: `node`, `substrate`, `daemon`, `config`, `completion`.

Read [references/hive-commands.md](references/hive-commands.md) for detailed command syntax and [references/hive-patterns.md](references/hive-patterns.md) for operational patterns.

## Safety Rules

- Start with one bee or a tiny swarm, prove readiness and output shape, then scale.
- Treat `blocked`, `node_unreachable`, `kill_failed`, and readiness timeouts as hard operational signals. Inspect before retrying.
- A readiness timeout is **not** death. The boot probe timed out; the process may still be coming up. Inspect the pane (`hive tail <bee>` / `hive attach <bee> --print`) before respawning, and never declare a bee dead from a probe timeout alone. Note `hive ps` can show a stale `working` for a bee whose tmux pane has actually exited — confirm liveness with `hive tail` (a dead pane prints "tmux pane is not running").
- Bind credentials with `--account <name|auto>` (or the `<tool>-<account>` shorthand, e.g. `hive spawn codex-auto`), not `--home`. A *home* is a slot (the "where"); an *account* is the identity (the "who") and `--account` activates it into a free home. `--account auto` picks a free credentialed account — use it for codex/claude/opencode rather than hand-picking a home.
- Codex bees timing out on boot while many share one `CODEX_HOME` is a credential-collision symptom (single-use OAuth refresh tokens race on concurrent boot), **not** general flakiness. Spread load across accounts with `--account auto`, and never spawn onto the current session's own account home.
- Use `--yolo` deliberately. Claude defaults to permissionless; use `--no-yolo` when approvals matter.
- Use `--no-wait` only when an upper layer will check readiness later.
- Prefer `--background` flow runs and loops for durable async work; always record the run id.
- Do not search transcripts with `hive search`; it searches seals, ledger, and session records only.
- End bees with `hive retire` (archives the record, stays revivable), **not** `hive kill`. Reserve `hive kill --yes` for a true purge (it deletes the record, seals, and run dir irreversibly).
- After a substrate crash (tmux server died, taking every pane), recover the whole fleet with `hive revive --crashed` — it revives exactly the un-commanded deaths (`crashed` state), skips retired/sealed bees, and auto-drives claude's startup dialogs. Use `--no-wait` to skip the post-relaunch readiness wait.
- Clean dead metadata with `hive clean --dead --dry-run` before destructive cleanup.
- For long or expensive bees, watch API-equivalent cost with `hive spend usage` and `hive spend session <bee>`. A session whose context-per-turn climbs toward the model's cap is hoarding context — cache-read tokens dominate the bill and it will compact sooner. Compact, checkpoint, or externalize state instead of letting context grow unbounded.

## Common Examples

```sh
hive run codex --account auto -p "Inspect this repo and seal a risk summary." --cwd "$PWD" --wait --last
hive spawn codex --count 8 --account auto --cwd "$PWD" --colony audit --swarm-id audit-pass-001
hive send @audit-pass-001 "Each take a different module. Seal findings as JSON."
hive wait CO.a3f --seal
hive flow run deep-review --arg target=src --background
hive loop start --bee codex --cwd "$PWD" --context rolling --max 50 --prompt-file ./loop-task.md
```

Pass harness args after `--` (precedence FLAG > profile > account default). To pin a known-good codex model/effort:

```sh
hive spawn codex --account auto --cwd "$PWD" -- -m gpt-5.5 -c 'model_reasoning_effort="xhigh"'
```

Ground truth beats `--help` (a terse one-line usage). `hive ps --wide` prints the exact command line of every live bee — copy a known-good invocation (model pin, account home) from a working bee rather than guessing flags.

## Output Contract

When using this skill, report the selected primitive, exact commands run or recommended, selectors/run ids created, how output will be collected, and the stop/cleanup command.
