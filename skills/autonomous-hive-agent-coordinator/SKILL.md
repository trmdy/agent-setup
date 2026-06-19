---
name: autonomous-hive-agent-coordinator
description: Coordinate complex asynchronous multi-agent work with Honeybee `hive` and Pollinate. Use when Codex must plan, launch, ramp, monitor, message, collect, merge, stop, or recover many hive agents, from a few Claude/Codex/Grok bees to tens, hundreds, or thousands of sharded asynchronous agents, including Pollinate-triggered schedules/webhooks/polls and Hive flows/loops.
---

# Autonomous Hive Agent Coordinator

Use this skill to act as the orchestration layer above Honeybee and Pollinate. Honeybee executes and observes agents; Pollinate fires triggers; the coordinator owns decomposition, routing, policy, quality gates, and merge judgment.

## Coordination Model

1. Define the mission in external artifacts: task list, shard map, output schema, stop conditions, owner, and cleanup policy.
2. Prove the path with one bee. Then run a tiny swarm. Only then scale.
3. Use Hive for execution: sessions, swarms, frames, flows, loops, buz, seals, search.
4. Use Pollinate for activation: schedules, polls, webhooks, router bindings, batching/debouncing.
5. Treat seals and ledgers as the contract. Do not coordinate from screenshots or vague pane reads when structured output is possible.
6. Use dynamic workflow structure to prevent partial completion, self-review bias, and goal drift: isolate worker contexts, add verifier agents, and keep the control loop outside worker prompts.
7. Use native harness features through Hive when they fit. A Hive bee is still a Claude/Codex/OpenCode/Grok/Pi/Droid session, so prompts may invoke supported native features such as `/goal`, `/loop`, model modes, or built-in review/research tools. Verify per harness before relying on them.

Read [references/orchestration-playbook.md](references/orchestration-playbook.md) for launch/ramp/monitor/stop patterns and [references/scale-patterns.md](references/scale-patterns.md) for high-scale sharding and backpressure.

## Launch Checklist

- Scope: write the work queue and shard boundaries.
- Output contract: define required seal fields, artifact paths, and status values.
- Harness mix: choose bee kinds and auth homes; reserve scarce profiles.
- CWD and permissions: set `--cwd`, node, yolo/approval policy, and tool limits.
- Backpressure: set max concurrent bees/jobs per harness/node.
- Stop: define success, timeout, max iterations, and kill/cleanup commands.
- Observability: record swarm ids, flow run ids, loop ids, Pollinate trigger/job ids.
- Budget: set max live bees, max token/tool budget when known, max retries, and any commands workers must avoid.

## Primitive Selection

- Small one-off: `hive run` or `hive x`.
- One cohort, one assignment: `hive spawn --count` and `hive send @swarm`.
- Role split: `hive frame define`, `hive spawn --frame --briefed`.
- Programmatic fan-out/collect: TS `hive flow`.
- Repetitive queue work: `hive loop start`.
- External events/time: Pollinate trigger action to `honeybee-flow`, `honeybee-loop`, `honeybee-spawn`, or `honeybee-send`.
- Per-subject long-lived external thread: Pollinate router.
- Adversarial or taste work: generate/filter or tournament flow.
- Unknown amount of work: loop-until-done with mechanical stop conditions.

## Ramp Pattern

```sh
# 1. State
hive ps --wide
pol status

# 2. Proof
hive run codex -p "Do shard 0 only. Seal JSON." --cwd "$PWD" --wait --last

# 3. Tiny swarm
hive spawn codex --count 3 --cwd "$PWD" --colony mission-x --swarm-id mission-x-proof
hive send @mission-x-proof "Take shard IDs 1-3 from shard-map.json. Seal one result each."

# 4. Scale via flow or repeated bounded batches
hive flow run mission-x-fanout --arg shardStart=4 --arg shardCount=50 --background
```

Only increase concurrency after outputs are valid and the monitor loop is working.

## Coordination Contracts

- Every bee gets a unique shard and a clear finish condition.
- Every bee reports status through a seal or explicit queue message.
- Every shard has exactly one owner at a time.
- Merge agents do not modify worker artifacts in place; they produce a merge artifact.
- Review agents challenge merged output against raw seals.
- Coordinators pause or stop swarms when duplicate work, blocked state, or runaway retries appear.

## Pollinate Integration

Use Pollinate when work should start from time or events:

```sh
pol create nightly-research --source schedule --cron '0 2 * * *' --timezone Europe/Oslo \
  --cwd "$PWD" --delivery immediate --max-concurrent 1 \
  --action honeybee-flow --flow research-fanout --arg date='{{fired_at}}'

pol create event-swarm --source webhook --path mission/event --delivery debounced --quiet-period 2m \
  --cwd "$PWD" --action honeybee-flow --flow event-triage --arg event='{{batch}}'
```

## Safety Rules

- Never jump directly to huge concurrency. Ramp from 1 to 3-10 to larger batches.
- Do not spawn thousands of live interactive tmux agents unless nodes, auth homes, API quotas, and cleanup are explicitly planned. Prefer Pollinate batches, Hive flows, loops, and queued shards.
- Cap per-node and per-harness concurrency; leave headroom for coordinator/reviewer agents.
- Use `--background` flows for durable work and save run ids.
- Use `hive flow cancel`, `hive loop stop --now`, and `hive kill` as first-class rollback steps.
- Prefer `queue`/`passive` `buz` for async coordination; reserve `interrupt` for urgent control.
- Treat provider auth homes as capacity-limited resources.
- Use mechanical stop conditions before LLM judge conditions.
- Quarantine untrusted external content. Reader bees may process public input; action bees perform privileged operations only from sanitized summaries.

## Output Contract

When using this skill, produce a concrete orchestration packet: shard plan, commands or flow/trigger definitions, ramp schedule, monitor commands, collection/merge contract, stop criteria, and cleanup/recovery commands.
