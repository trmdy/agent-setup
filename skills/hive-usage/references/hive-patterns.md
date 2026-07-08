# Hive Operational Patterns

## Contents

- Single-Agent Probe
- Small Swarm Review
- Differentiated Swarm
- Coordinator With Buz
- Flow-Based Fan-Out
- Loop-Based Queue Work
- Failure Playbook

## Single-Agent Probe

Use a one-agent proof whenever the task is new, risky, or likely to hit trust prompts.

```sh
hive run codex -p "Inspect the repo and seal a plan. Do not edit." --cwd "$PWD" --wait --last
```

Success criteria:

- Bee reaches `ready`, `active`, then `idle` or `sealed`.
- Output matches the requested contract.
- No `blocked`, MCP warning, trust prompt, or permission prompt.

## Small Swarm Review

Use for broad inspection where each bee can own a disjoint slice.

```sh
hive spawn codex --count 6 --cwd "$PWD" --colony review --swarm-id review-001
hive send @review-001 "Choose a different top-level directory. Report one seal with findings, risk, and suggested tests."
```

Coordinator loop:

```sh
hive ps --swarm review-001 --wide
hive seals find "status" --swarm review-001 --json
hive wait <bee> --seal
```

Avoid duplicate work by assigning slices explicitly when possible.

## Differentiated Swarm

Use frames when roles differ.

1. Define a frame with castes and role briefs.
2. Spawn `--briefed` to preload context but leave agents waiting.
3. Send role-specific assignments.
4. Collect seals, merge, then ask reviewers to challenge the merge.

```sh
hive frame define ./review.frame.json
hive spawn --frame deep-review --cwd "$PWD" --colony product --swarm-id dr-001 --briefed
```

Current stable selectors are bee id, `@swarm`, and `colony:name`; caste selectors are a spec direction, not a stable selector.

## Coordinator With Buz

Use `buz` for durable async messages between long-lived bees:

```sh
hive buz send CO.plan --sender-human coordinator --tier queue --subject assignment -p "Shard src/flow into 8 packets."
hive buz inbox CO.plan
hive buz read <message-id> --bee CO.plan --consume
```

Use direct `send` for immediate action; use `buz queue` for work that should wait until the bee is ready.

## Flow-Based Fan-Out

Use a saved TS flow when orchestration needs loops, parallelism, conditional handling, or collection:

```ts
import { defineFlow } from "honeybee/flow";

export default defineFlow({
  name: "fanout-review",
  args: [{ name: "target", default: "src" }],
  cleanup: "keep",
  run: async (ctx) => {
    const shards = ["cli", "flow", "loop", "pollinate"];
    const bees = await Promise.all(shards.map((shard) =>
      ctx.hive.spawn({ bee: "codex", cwd: String(ctx.args.target), colony: "review", swarmId: `review-${ctx.runId}` })
        .then((bee) => ({ bee, shard })),
    ));
    await Promise.all(bees.map(({ bee, shard }) =>
      ctx.hive.brief(bee, `Review shard ${shard}. Seal JSON with findings and confidence.`),
    ));
    const seals = await Promise.all(bees.map(({ bee }) => ctx.hive.waitForSeal(bee, { timeoutMs: 900000 })));
    await ctx.hive.log(`collected ${seals.length} seals`);
    return { seals: seals.length };
  },
});
```

## Loop-Based Queue Work

Use `hive loop start` when the task is repetitive and can be re-derived from disk each pass:

```sh
hive loop start --bee codex --cwd "$PWD" --context ralph --max 200 \
  --prompt "Take the next unchecked item in TODO.md, implement it, update TODO.md, and seal." \
  --until 'test -z "$(grep -F "[ ]" TODO.md)"'
```

Prefer:

- `ralph` for very long horizons and work queues.
- `rolling` when memory matters but fresh context matters more.
- `persistent` for short loops where harness memory is useful.

## Failure Playbook

`blocked`: inspect pane with `hive tail`, then `hive attach` if human approval is required. Do not keep sending prompts.

Readiness timeout (esp. codex on boot): a probe timeout is **not** death — inspect first (`hive tail <bee>` / `hive attach <bee> --print`), and remember `hive ps` may show a stale `working` for a bee whose pane has exited (a dead pane prints "tmux pane is not running"). Do not respawn blindly; each blind respawn leaves an orphan. Leading causes, in order: (1) **credential collision** — many bees sharing one `CODEX_HOME` race the single-use OAuth refresh token on concurrent boot; fix by spreading across accounts with `--account auto`, never the current session's own account home. (2) **uncredentialed home** — a bare `hive x codex` may land on a home with no creds; bind one with `--account <name|auto>`. (3) **bad/default model config** — copy a known-good invocation from a live bee (`hive ps --wide` shows it, e.g. `-- -m gpt-5.5`). Prove one bee with `hive run <bee> --account auto -p "…" --wait --last` before scaling. End bees you no longer need with `hive retire` (archives, revivable); reserve `hive kill --yes` / `hive clean --dead --dry-run` for truly purging orphaned records.

`node_unreachable`: check `hive node inspect`, SSH/Tailscale reachability, and avoid broad cleanup until node status is known.

`kill_failed`/`retire_failed`: use `hive attach --print` or substrate-native tmux commands to verify process state. Retry `hive retire` (or `hive kill`) only after understanding why the prior teardown failed.

`crashed`: the record is live but its session/host is gone with no retire/kill on record — an un-commanded death (tmux server crash, external kill, harness exit). Recover the whole fleet at once with `hive revive --crashed` (revives exactly the crashed bees, skips retired/sealed, prints a tmux-server-age diagnosis, and auto-drives claude's startup dialogs). `--fresh` starts a new provider session and clears the stale id; `--no-wait` skips the readiness wait. End bees deliberately with `hive retire` (archives, stays revivable), never `hive kill` unless you truly mean to purge the record + seals.

No seal: use `hive wait --last` or `hive transcript` for recovery, then ask the bee to seal explicitly.

Harness-native feature mismatch: if a prompt uses `/goal`, `/loop`, or another native harness command, first confirm the selected bee supports that command. Hive will deliver the text, but the harness decides what it means.

Duplicate swarm work: pause with `hive send @swarm "Stop after current thought. Wait for assignments."`, assign explicit shards, then resume.

Runaway flow/loop: `hive flow cancel <runId>` or `hive loop stop <loopId> --now`, then inspect logs before restarting.
