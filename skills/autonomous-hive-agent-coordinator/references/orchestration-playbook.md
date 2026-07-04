# Autonomous Hive Orchestration Playbook

## Contents

- Stack Boundary
- Mission Packet
- Coordinator State And Context Hygiene
- Launch Sequence
- Monitoring Loop
- Assignment Patterns
- Collection And Merge
- Recovery

## Stack Boundary

Use this split:

```text
coordinator = why, decomposition, routing, policy, merge judgment
hive        = execute, address, message, wait, collect, state, seal, search
pollinate   = fire from schedules, polls, webhooks, router events
```

Do not ask Honeybee or Pollinate to decide mission strategy. Encode strategy in prompts, shard files, flows, trigger definitions, and review contracts.

Hive does not strip native harness capabilities. It gives the coordinator a durable way to spawn and message native harness sessions. If Claude Code has `/goal` or `/loop`, or another harness has a native review/research/tool mode, a Hive-controlled bee can be instructed to use it. This is harness-specific pass-through behavior, not a universal Hive command.

## Mission Packet

Before spawning more than one bee, write or identify:

- `mission.md`: goal, constraints, non-goals, output format.
- `shards.jsonl` or task system: one record per independent unit.
- `assignments.jsonl`: shard id, bee id, state, timestamps.
- `seal.schema.json` or explicit JSON fields.
- `merge.md`: how collection and conflict resolution works.
- stop policy: max agents, max duration, success check, manual hold point.
- budget policy: token/tool budget if supplied, max live bees, max retries, and forbidden resource-heavy commands.

Minimal seal schema:

```json
{
  "status": "done|blocked|needs_input|failed",
  "shard_id": "string",
  "summary": "string",
  "artifacts": ["path"],
  "risks": ["string"],
  "confidence": 0.0,
  "next": "string"
}
```

## Coordinator State And Context Hygiene

The coordinator's own context is a first-class reliability and cost hazard. A long orchestration that tracks the fleet *in its head* loses bees the moment context compacts, and pays to re-read a swelling history every turn.

Rules:

- **The assignments file is the source of truth, not the transcript.** Append to `assignments.jsonl` the instant you spawn (shard id, bee id, state, timestamps). Re-read it at the top of every cycle. Never route from memory.
- **Reconcile against ground truth each cycle.** `hive ps` is what is actually alive; `assignments.jsonl` is what you think you launched. Diff them: bees in `ps` not in your file are orphans (adopt or kill); assignments with no live bee are done, dead, or lost (check the seal, re-dispatch, or close).
- **Keep the coordinator lean.** Push detail into worker seals and the assignments file, not the coordinator prompt. The coordinator should read *summaries and status*, not full worker transcripts. Carrying every worker's output is what drives the context toward the cap.
- **Checkpoint before you compact.** Write a compact `fleet-state.md` (open shards, live bees, blockers, decisions) on a cadence. If context compacts (or the coordinator is resumed/forked), rebuild from `fleet-state.md` + `hive ps` + seals, not from what survived in-context.
- **Externalize decisions, not just data.** Record *why* a shard was routed a certain way, so a resumed coordinator doesn't re-litigate or contradict itself.

Reconcile sketch:

```sh
# What is alive vs what you recorded
hive ps --colony mission --wide --json > live.json
# For each assignment with state=working but no live bee → inspect its last seal
hive seals find '"shard_id"' --colony mission --since 24h --json > seals.json
# Coordinator diffs live.json against assignments.jsonl and seals.json, then acts.
```

Symptom that you skipped this: "I lost track of a bee across compaction," duplicate shard work, or spawning past your concurrency cap because the old bees fell out of context. The fix is always to reconcile from `hive ps` + files, never to remember harder.

## Launch Sequence

1. Preflight:

```sh
hive ps --wide
hive node list
hive daemon status --json
pol status
```

2. Single proof:

```sh
hive run codex -p "$(cat prompts/worker-proof.md)" --cwd "$PWD" --wait --last
```

3. Tiny swarm:

```sh
hive spawn codex --count 3 --cwd "$PWD" --colony mission --swarm-id mission-proof
hive send @mission-proof "Take shard IDs 1-3. Seal JSON matching seal.schema.json."
hive ps --swarm mission-proof --wide
```

4. Validate collection:

```sh
hive seals find '"shard_id"' --colony mission --since 1h --json
hive search "prompt.run" --type ledger --since 1h
```

5. Ramp:

Use batches. Example: `3 -> 10 -> 25 -> 50`, then repeat bounded batches rather than unlimited live agents.

## Monitoring Loop

Run every few minutes while the swarm is active:

```sh
hive ps --colony mission --wide             # ground truth: what is alive now
hive search "flow.run" --type ledger --since 30m
hive seals find "blocked" --colony mission --since 30m
hive spend usage --granularity day          # cost by model so far today
pol jobs --last 20
pol ledger -n 50
```

Reconcile `hive ps` against `assignments.jsonl` (see Coordinator State And Context Hygiene) before routing anything new.

Check:

- Are new seals arriving?
- Are many bees `blocked`, `offline`, or `kill_failed`?
- Are multiple bees working the same shard?
- Do live bees and your assignments file agree? (orphans / lost bees)
- Are output artifacts valid against the schema?
- Is queue depth/concurrency within capacity?
- Is spend tracking the value delivered, and is the model mix right for the work? (`hive spend session <coordinator>` if the coordinator itself looks expensive)

## Assignment Patterns

Static shard assignment:

```sh
hive send CO.a3f "You own shard 017 only. Do not work any other shard."
```

Pull-based queue assignment:

- Put shard records in a file or task system.
- Require atomic claim protocol.
- Bees must record claim before work.
- Bees must release or mark blocked on failure.

Buz assignment:

```sh
hive buz send CO.a3f --sender-human coordinator --tier queue \
  --subject shard.assign -p "shard_id=017; read shards/017.md; seal JSON."
```

Use direct `send` for immediate action; use `buz queue` for work that should wait until the bee is ready.

## Dynamic Workflow Patterns

Classify-and-act:

- First classifier determines shard type, required bee kind, risk, or action path.
- Coordinator routes each shard accordingly.

Fan-out-and-synthesize:

- Workers operate on disjoint shards.
- Synthesizer waits for all worker seals and merges.

Adversarial verification:

- Verifier agents check worker outputs against raw evidence and a rubric.
- Do not let the original worker judge itself.

Generate-and-filter:

- Many agents produce candidate ideas or fixes.
- Filter, dedupe, verify, and return only the strongest.

Tournament:

- Competing agents solve the same task.
- Judge pairwise until a winner or top set emerges.

Loop-until-done:

- Repeat until a mechanical stop: tests pass, queue empty, no new findings, or no log errors.
- Use `hive loop` or a TS flow with bounded iterations.

Quarantine triage:

- Agents reading untrusted external content cannot take privileged actions.
- Separate action agents receive sanitized summaries and explicit commands.

## Collection And Merge

Collection:

```sh
hive seals find "shard_id" --colony mission --since 24h --json > seals.json
```

Merge flow:

1. Normalize seals into one result table.
2. Separate `done`, `blocked`, `needs_input`, `failed`.
3. Deduplicate by shard id and latest `sealedAt`.
4. Run a merge bee on normalized results.
5. Run a review bee that sees both raw seals and merged output.
6. Only then close the mission.

Challenge prompt:

```text
Review merged-result.md against raw seals.json. Find missing shards, overclaims,
contradictions, and unhandled blocked items. Do not edit. Seal review JSON.
```

## Recovery

Blocked swarm:

```sh
hive ps --swarm mission-001 --wide
hive tail <blocked-bee> -n 160
hive attach <blocked-bee>
```

Duplicate work:

```sh
hive send @mission-001 "Stop after current thought. Do not claim new shards. Wait."
```

Then rewrite assignments and resume by explicit bee id.

Coordinator lost track of the fleet (compaction, resume, or fork):

```sh
hive ps --colony mission --wide --json > live.json         # what is actually alive
hive seals find '"shard_id"' --colony mission --since 24h --json > seals.json
```

Rebuild `fleet-state.md` from `live.json` + `seals.json` + `assignments.jsonl` — never from what survived in-context. Adopt orphaned bees, close shards that have a `done` seal, re-dispatch shards whose bee is gone. Then continue from the reconciled file.

Runaway flow:

```sh
hive flow status <runId> --json
hive flow logs <runId>
hive flow cancel <runId>
```

Runaway loop:

```sh
hive loop status <loopId> --json
hive loop stop <loopId> --now
```

Dead or stale metadata:

```sh
hive clean --dead --dry-run
hive clean --dead --older-than 7d
```

Pollinate failure:

```sh
pol job <jobId>
pol ledger -n 100
pol trigger <triggerId> --dry-run --payload '{"debug":true}'
```
