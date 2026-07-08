# Hive Command Reference

## Contents

- Install And Identity
- Spawning
- One-Shot And Fire-And-Forget
- Addressing And Inspection
- Messaging
- Seals, Search, And Handoffs
- Flow Commands
- Loop Commands
- Nodes And Daemon
- Cleanup

## Install And Identity

Honeybee exposes `hive`; `ap` may exist as a compatibility alias. Sessions live under `~/.hive`.

```sh
npm install
npm run build
npm link
hive --help
hive config show
hive config path
```

Agent kinds are `claude`, `codex`, `opencode`, `grok`, `pi`, `droid`, plus arbitrary executables. Auth aliases include `codex1`, `codex2`, `codex3`, `cc1`, `cc2`, `cc3`.

Hive starts and steers the native harness process. Prompts sent with `hive send`, `hive brief`, `hive run`, `hive x`, or flow/loop facade calls are delivered into that harness, so bees can use native harness features when the harness supports them. Examples include Claude Code slash commands and modes such as `/goal` or `/loop`, Codex/Claude/OpenCode/Grok built-in tools, model/profile switches, and harness-specific review or planning features. Do not assume one harness supports another harness's command set; check the harness help or run a small proof bee.

Command override environment variables:

```sh
HIVE_CLAUDE_CMD="claude --model sonnet" hive spawn claude
HIVE_DROID_CMD="python3 ~/bin/droid-agent.py" hive spawn droid
HIVE_CODEX_YOLO=1 hive spawn codex
```

`HIVE_<AGENT>_CMD` is parsed as argv-style words, not shell syntax. Use `env NAME=value command ...` inside the override if needed.

## Spawning

Single bee:

```sh
hive spawn codex --cwd "$PWD"
hive spawn codex2 --cwd "$PWD"
hive spawn claude --home ~/.claude-3 --cwd "$PWD"
hive spawn grok --node mini01 --cwd "$PWD"
```

Spawn waits for readiness by default and accepts common startup trust prompts. Use `--no-accept-trust` to leave trust prompts untouched, `--no-wait` to return immediately, and `--force-send` only for `run`/`x` readiness timeouts.

Yolo policy:

- Claude defaults to permissionless (`claude --dangerously-skip-permissions`).
- `codex`, `opencode`, and `grok` need `--yolo` or env/config opt-in for bypass mode.
- Use `--no-yolo` when approval prompts are desired.

Homogeneous swarm:

```sh
hive spawn codex --count 12 --cwd "$PWD" --colony audit --swarm-id audit-001 --yolo
hive send @audit-001 "Split by directory. Seal one JSON finding file per bee."
```

Frame-backed swarm:

```json
{
  "name": "deep-review",
  "description": "Architect, implementer, reviewer split",
  "castes": [
    { "name": "architect", "bee": "claude", "count": 1, "brief": "Map architecture and risks. Wait for assignment." },
    { "name": "implementer", "bee": "codex", "count": 4, "brief": "Take isolated implementation tasks. Wait for assignment." },
    { "name": "reviewer", "bee": "grok", "count": 2, "brief": "Review outputs. Wait for assignment." }
  ]
}
```

```sh
hive frame define ./deep-review.frame.json
hive spawn --frame deep-review --cwd "$PWD" --colony honeybee --swarm-id review-001 --briefed
hive swarm inspect @review-001
```

## One-Shot And Fire-And-Forget

`run` spawns, sends a prompt, optionally waits, and can clean up:

```sh
hive run codex -p "Review src/cli.ts. Seal JSON risks." --cwd "$PWD" --wait --last
hive run claude -p "Inspect this repo." --accept-trust --wait --transcript
hive run codex -p "Smoke test this." --wait --last --rm
```

`x` spawns a single bee, sends a prompt, and returns immediately:

```sh
hive x codex "Summarize this repo and seal key risks." --cwd "$PWD" --yolo
hive wait CO.a3f --seal
```

## Addressing And Inspection

Selectors:

- Bee id/name: `CO.a3f`, `CL.91b`, explicit `--name`.
- Swarm: `@review-001`.
- Colony: `colony:honeybee`.

Inspect:

```sh
hive ps --wide
hive ps --colony honeybee
hive ps --swarm review-001
hive tail CO.a3f -n 120
hive tail CO.a3f -f
hive transcript CO.a3f --json
hive last CO.a3f
hive wait CO.a3f --last
hive wait CO.a3f --seal
hive attach CO.a3f --print
```

State labels include `booting`, `ready`, `active`, `idle`, `blocked`, `sealed`, `crashed`, `archived`, `dead`, `kill_failed`, and `offline`. Treat `blocked` as a required human/owner intervention unless the next command intentionally resolves trust/permission.

- **`crashed`** — the record is still live but its tmux session / HSR host is gone AND no retire/kill was issued: an un-commanded death (tmux server crash, external kill, harness exit). This is the state to recover with `hive revive --crashed`. Distinct from `dead` (only explicitly-marked/legacy records) and from `archived` (deliberately retired).
- **`archived`** — the bee was deliberately retired (`hive retire`/`archive`). Settled on purpose; excluded from the active list and from bulk revive, but still revivable by name.

## Messaging

Direct prompts:

```sh
hive send CO.a3f "Proceed with the next file."
hive brief @review-001 "Shared context: target is src/flow. Wait for your assignment."
```

`brief` adds a halt-and-wait footer by default. Use `send` when the target should act immediately.

`buz` is file-backed addressed messaging with tiers:

- `interrupt`: delivered into the pane immediately if accepted.
- `queue`: durable inbox item for next processing.
- `passive`: low-priority message.

```sh
hive buz config CO.a3f
hive buz config CO.a3f --accept interrupt,queue,passive
hive buz send CO.a3f --sender-human coordinator --tier queue --subject task.assign -p "Take package src/flow."
hive buz inbox CO.a3f --limit 10
hive buz read <message-id> --bee CO.a3f --consume
hive buz purge CO.a3f --read
```

Default accept policy is `queue,passive`. `interrupt` can be downgraded based on per-bee policy.

## Seals, Search, And Handoffs

Seals are typed handoff artifacts. Use them when downstream code or a coordinator must consume structured status.

```sh
hive seal CO.a3f --from ./seal.json
hive last CO.a3f --seal
hive seals find "regression" --colony honeybee --since 7d
hive search "flow.run" --type ledger --since 24h --json
```

`hive search` covers seals, ledger, and session records, including rotated ledgers. It intentionally does not search provider transcripts.

## Flow Commands

```sh
hive flow define ./deep-review.json
hive flow define ./deep-review.ts
hive flow list
hive flow inspect deep-review
hive flow run deep-review --arg target=src --background
hive flow runs --flow deep-review
hive flow status <runId> --json
hive flow logs <runId>
hive flow cancel <runId>
hive flow remove deep-review
```

Foreground flow runs return when done. Background flow runs fork a process group and print a run id; `cancel` signals that group. `cleanup: "kill-on-end"` kills bees spawned by the flow at completion/cancel/failure; default `keep` leaves them inspectable.

## Loop Commands

```sh
hive loop start --bee codex --cwd "$PWD" --context persistent --max 20 --prompt "Work the next TODO item, then seal."
hive loop start --bee codex --cwd "$PWD" --context rolling --max 200 --prompt-file ./loop-task.md --summarizer self
hive loop start --bee claude --cwd "$PWD" --context ralph --max 100 --until 'npm test' --prompt "Fix the next test failure and seal."
hive loop status <loopId> --json
hive loop logs <loopId> -n 120
hive loop logs <loopId> --iter 3
hive loop stop <loopId>
hive loop stop <loopId> --now
```

Context modes:

- `persistent`: one bee, harness memory.
- `ralph`: fresh bee each iteration, no memory except disk/repo.
- `rolling`: fresh bee each iteration, hive-maintained `progress.md`/history.

Use `--max` unless `--forever` is intentional. Favor mechanical stops: `--until`, `--max-duration`, `--stop-on-seal`, `--stop-on-sentinel`.

## Nodes And Daemon

Nodes are execution endpoints. `local` always exists; registered `ssh-tmux` nodes route sessions over SSH.

```sh
hive substrate list
hive node list
hive node register mini01 --host mini01 --user trmd
hive node inspect mini01
hive spawn codex --node mini01 --cwd /Users/trmd/Projects/foo
```

The daemon drains `buz` and derives state. On macOS it is launchctl-managed.

```sh
hive daemon install
hive daemon start
hive daemon status --json
hive daemon logs --lines 100 --follow
hive daemon stop
```

## Revive

```sh
hive revive CO.a3f                 # relaunch a dead/crashed bee, resume its provider session
hive revive CO.a3f --fresh         # start a new session instead (clears the stale session id)
hive revive CO.a3f --session <id>  # resume a specific provider session id
hive revive --crashed              # revive ALL crashed bees (post tmux-server-crash recovery)
hive revive --all                  # revive every non-archived dead/crashed local bee
hive revive --crashed --no-wait    # skip the post-relaunch readiness wait
```

Revive resumes a bee in its own cwd/home with no account switch, waits for readiness, and auto-drives claude's startup dialogs (trust, bypass-permissions, resume-mode chooser, renderer tour). It also refreshes the bee's home credentials from the vault first, so a bee whose token expired while it was dead does not boot logged-out. `--crashed` targets exactly the un-commanded deaths and skips sealed bees; both `--crashed` and `--all` exclude retired (`archived`) bees. Retired bees stay revivable individually by name.

## Ending bees: retire (everyday) vs kill (rare purge)

```sh
hive retire CO.a3f                 # everyday stop: tears down the runtime, ARCHIVES the record
hive retire @review-001            # retire a whole swarm (also colony:name, tags)
hive archive CO.a3f                # alias of retire
hive kill CO.a3f --yes             # RARE purge: also deletes record + seals + run dir (prompts without --yes)
hive swarm destroy @review-001     # retires each member (records kept)
hive clean --dead --dry-run
hive clean --dead --older-than 7d
hive clean --idle --older-than 30m --dry-run
```

- **`hive retire <bee|@swarm|colony:name>`** (alias `archive`) is the everyday way to end a bee: it stops the tmux session / HSR runner and sets the record to `archived`. Seals, ledger history, and the provider session all survive, and the bee stays **revivable**. This is what `swarm destroy`, `run --rm`, flow `kill-on-end`, and the bees-TUI kill key now do.
- **`hive kill <bee>`** is the rare garbage collector: it stops the bee AND permanently deletes its session record, seals, and HSR run dir — not revivable afterwards. It prompts `y/N` on a TTY and requires `--yes`/`--force` when scripted. Use it only to truly purge a bee; reach for `retire` otherwise.
- Use dry runs before broad cleanup. `kill_failed`/`retire_failed` records are not cosmetic; inspect and retry or manually kill the tmux session.
