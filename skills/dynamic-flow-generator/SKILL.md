---
name: dynamic-flow-generator
description: Generate ad-hoc and saved Honeybee `hive flow` templates for fan-out/fan-in, multi-agent coordination, loops, router-triggered work, collection, merge/review stages, and reusable orchestration recipes. Use when Codex must design, write, register, run, or explain JSON or TypeScript Hive flows, especially dynamic flows that spawn many agents, coordinate via buz/seals, loop until stop conditions, or integrate with Pollinate triggers.
---

# Dynamic Flow Generator

Use this skill to turn an orchestration idea into a runnable Hive flow or a small family of flows plus Pollinate triggers. Prefer JSON flows for linear deterministic scripts; use TypeScript flows for parallelism, loops, conditionals, dynamic shard generation, buz primitives, and collection logic.

Hive flows send text into native harness sessions. Flow prompts can instruct bees to use native harness capabilities such as `/goal`, `/loop`, built-in research/review modes, or model/tool features when the selected bee supports them. Do not bake a harness-specific command into a reusable flow without documenting the required bee kind.

## Decision Tree

- Need only sequential spawn/send/wait/kill/log? Generate a JSON flow.
- Need fan-out/fan-in, loops, conditionals, dynamic shard lists, or custom merge logic? Generate a TypeScript flow.
- Need continuous repeated work? Generate a flow that starts `ctx.hive.loop(...)`, or use `hive loop start` directly.
- Need time/webhook/poll activation? Generate the flow plus a Pollinate trigger.
- Need one long-lived agent per external subject? Use a Pollinate router, not a standalone flow per event.

Read [references/flow-authoring.md](references/flow-authoring.md) for exact Hive flow syntax and [references/flow-templates.md](references/flow-templates.md) for reusable patterns.
Read [references/dynamic-workflow-patterns.md](references/dynamic-workflow-patterns.md) when the request resembles Claude Code dynamic workflows: custom task-specific harnesses, adversarial panels, tournaments, large-scale sorting, deep research, triage, or loop-until-done work.

## Generation Workflow

1. Capture parameters: target cwd, shard source, concurrency, bee kinds, node/profile constraints, output schema, cleanup mode, stop conditions.
2. Choose the workflow pattern: classify-and-act, fan-out/synthesize, adversarial verification, generate/filter, tournament, loop-until-done, or quarantine triage.
3. Pick JSON or TS. Use TS for most multi-agent dynamic flows.
4. Write a flow file with stable `name`, `description`, `args`, `cleanup`, and `run`.
5. Register and inspect:

```sh
hive flow define ./my-flow.ts
hive flow inspect my-flow
```

6. Run a tiny proof:

```sh
hive flow run my-flow --arg limit=2
```

7. Run durable work in background:

```sh
hive flow run my-flow --arg limit=50 --background
hive flow status <runId> --json
hive flow logs <runId>
```

8. Add a Pollinate trigger only after the flow works manually.

## Flow Design Rules

- Give every spawned bee a shard id and output contract.
- Use `ctx.runId` in swarm ids and artifact names.
- Use bounded concurrency. Do not `Promise.all` thousands of spawns at once.
- Wait on seals for work that needs structured collection.
- Use `ctx.hive.log` for coordinator-visible progress.
- Use `cleanup: "keep"` while developing; switch to `kill-on-end` only when output collection is complete and panes do not need inspection.
- Surface run ids, loop ids, and spawned bee names in the flow return value or logs.
- Prefer mechanical validation before review bees.
- Add an explicit budget when the workflow could fan out aggressively: shard count, concurrency, max iterations, wall-clock timeout, and expected token/tool cost.
- Do not use a workflow when a single normal coding pass is enough; dynamic flows spend more tokens and add coordination overhead.

## Minimal TS Pattern

```ts
import { defineFlow } from "honeybee/flow";

export default defineFlow({
  name: "two-agent-review",
  description: "Spawn two reviewers and collect seals.",
  args: [{ name: "cwd", default: process.cwd() }],
  cleanup: "keep",
  run: async (ctx) => {
    const cwd = String(ctx.args.cwd);
    const swarmId = `two-agent-review-${ctx.runId}`;
    const a = await ctx.hive.spawn({ bee: "codex", cwd, swarmId });
    const b = await ctx.hive.spawn({ bee: "grok", cwd, swarmId });
    await Promise.all([
      ctx.hive.brief(a, "Review implementation. Seal JSON findings."),
      ctx.hive.brief(b, "Challenge the implementation. Seal JSON findings."),
    ]);
    const seals = await Promise.all([
      ctx.hive.waitForSeal(a, { timeoutMs: 900000 }),
      ctx.hive.waitForSeal(b, { timeoutMs: 900000 }),
    ]);
    await ctx.hive.log(`collected ${seals.length} seals`);
    return { swarmId, bees: [a.name, b.name], seals: seals.length };
  },
});
```

## Pollinate Activation Example

```sh
pol create review-on-webhook --source webhook --path review/start \
  --delivery debounced --quiet-period 30s --cwd "$PWD" \
  --action honeybee-flow --flow two-agent-review --arg cwd="$PWD"
```

## Output Contract

When using this skill, provide the flow file path/content, registration command, proof command, background run command, monitor/cancel commands, and any Pollinate trigger needed to activate it.
