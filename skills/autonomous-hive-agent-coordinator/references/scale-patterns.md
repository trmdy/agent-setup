# Scale Patterns For Large Hive Coordination

## Contents

- Scaling Rule
- Capacity Model
- Batch Runner Pattern
- Worker Pool Pattern
- Router Pattern
- Backpressure Tools
- Thousand-Unit Strategy
- Stop And Cleanup At Scale

## Scaling Rule

Scale live interactive agents only as far as observability and cleanup remain reliable. For hundreds or thousands of units, prefer a bounded worker pool over one live tmux session per unit.

Good high-scale shape:

```text
pollinate trigger -> hive flow -> spawn N workers -> workers pull/claim shards -> seals -> merge/review -> next batch
```

Where `N` is the concurrency cap, not total shard count.

## Capacity Model

Track:

- nodes available through `hive node list`
- auth homes/profiles available per harness
- API/provider quotas
- CPU/RAM on each node
- tmux session count
- coordinator and reviewer capacity
- expected artifact volume
- token/tool budget and forbidden high-cost commands

Do not consume all capacity with workers; reserve at least one coordinator and one reviewer channel.

## Batch Runner Pattern

Use a TS flow that accepts `shardStart`, `shardCount`, and `concurrency`, spawns up to `concurrency` bees, waits for seals, then exits. Pollinate can schedule or repeatedly fire that flow for the next batch.

```sh
hive flow run batch-worker --arg shardStart=0 --arg shardCount=100 --arg concurrency=20 --background
```

Monitor:

```sh
hive flow status <runId> --json
hive flow logs <runId>
hive ps --colony mission --wide
```

## Worker Pool Pattern

Use long-lived loop workers when each unit can be claimed from a durable queue:

```sh
hive loop start --bee codex --cwd "$PWD" --context ralph --max 500 \
  --prompt "Claim the next unclaimed shard from queue.jsonl, process it, update assignments.jsonl, and seal." \
  --until 'node scripts/queue-empty.js'
```

Start a small number of loops per node. This can process thousands of shards without thousands of simultaneous agents.

## Router Pattern

Use Pollinate routers for external subjects that need one long-lived target per subject, such as a GitHub PR:

```sh
pol github create-pr-router repo-pr-router --repo Owner/repo --cwd "$PWD" \
  --secret env:GITHUB_WEBHOOK_SECRET --reviewer codex=codex --reviewer grok=grok
```

This avoids creating a new agent for every comment while preserving subject affinity.

## Backpressure Tools

Hive:

- `--count N`: local cohort size.
- `--node <name>`: route to a substrate endpoint.
- `hive flow run --background`: detached bounded run.
- `hive loop start --max N`: iteration cap.
- `hive daemon`: drain/observe messages.

Pollinate:

- `maxConcurrent`: per-trigger job concurrency.
- `throttled`: cooldown.
- `batched`: grouped action.
- `debounced`: quiet-period action.
- router bindings: subject affinity.

## Thousand-Unit Strategy

Do not spawn 1000 bees unless explicitly required and capacity is proven. Prefer:

1. Create 1000 shard records.
2. Run 20-100 workers depending on capacity.
3. Each worker claims one shard at a time.
4. Each worker seals result and returns for another shard if loop-based, or exits if flow-batch-based.
5. Merge and review after every batch.
6. Pollinate schedules next batch or responds to queue changes.

## Pairwise Ranking At Scale

For sorting/ranking large qualitative lists:

1. Bucket items with lightweight classifiers.
2. Run pairwise comparison agents inside each bucket.
3. Merge bucket winners with a tournament bracket.
4. Re-check the top slice with verifier agents.

Comparative judgment is usually more reliable than asking one agent to score a huge table absolutely.

## Stop And Cleanup At Scale

Stop by scope:

```sh
hive send colony:mission "Stop after current shard. Seal status."
hive ps --colony mission --wide
hive retire colony:mission          # everyday stop for the whole colony (archives, revivable)
hive swarm destroy @mission-001     # retires each member (records kept)
hive flow cancel <runId>
hive loop stop <loopId>
```

Then, only to truly purge (records + seals + run dirs are gone, not revivable):

```sh
hive kill <bee> --yes               # rare; per-bee purge
hive clean --dead --dry-run
hive clean --dead --older-than 1d
```

If the tmux server itself crashed mid-run, the fleet lands in `crashed` (record live, session gone). Recover it before deciding anything is lost: `hive revive --crashed --no-wait`.

Never delete artifacts or assignment ledgers before merge/review completes.
