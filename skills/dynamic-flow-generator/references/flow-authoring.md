# Hive Flow Authoring Reference

## Contents

- Registry
- JSON Flow
- TypeScript Flow
- Cleanup
- Background Runs
- Bounded Parallel Helper Pattern
- Flow Plus Loop

## Registry

Flows are registered under `~/.hive/flows/<name>.json` or `.ts`; the original source path is persisted beside the copied flow.

```sh
hive flow define ./flow.json
hive flow define ./flow.ts
hive flow define ./flow.json custom-name
hive flow list
hive flow inspect <name>
hive flow run <name> --arg key=value
hive flow run <name> --background
hive flow runs --flow <name>
hive flow status <runId> --json
hive flow logs <runId>
hive flow cancel <runId>
hive flow remove <name>
```

`--arg` coerces `true`, `false`, and numeric literals; other values stay strings.

## JSON Flow

Use JSON when sequential ops are enough.

Supported ops:

- `spawn`
- `send`
- `brief`
- `waitForSeal`
- `wait`
- `kill`
- `seal`
- `log`
- `return`

Example:

```json
{
  "name": "linear-review",
  "description": "Spawn, brief, wait, return.",
  "args": [{ "name": "cwd", "default": "." }],
  "cleanup": "keep",
  "steps": [
    { "op": "spawn", "as": "reviewer", "bee": "codex", "cwd": "{{cwd}}", "swarmId": "linear-{{cwd}}" },
    { "op": "brief", "to": "{{reviewer.id}}", "text": "Review this repo and seal JSON findings." },
    { "op": "waitForSeal", "of": "{{reviewer.id}}", "timeoutMs": 900000 },
    { "op": "return", "value": { "status": "review-requested" } }
  ]
}
```

Substitution supports `{{name}}` and `{{name.field}}` from args and spawn bindings. Unknown placeholders remain literal, so typos are visible.

JSON cannot do parallelism, loops, conditionals, or dynamic shard generation. Use TypeScript for those.

## TypeScript Flow

Author with the SDK:

```ts
import { defineFlow } from "honeybee/flow";

export default defineFlow({
  name: "my-flow",
  description: "Readable one-line purpose.",
  args: [{ name: "cwd", default: process.cwd() }],
  cleanup: "keep",
  run: async (ctx) => {
    await ctx.hive.log(`run ${ctx.runId}`);
    return { ok: true };
  },
});
```

Context:

- `ctx.runId`
- `ctx.flowName`
- `ctx.args`
- `ctx.bindings`
- `ctx.signal`
- `ctx.hive`

Core facade:

```ts
ctx.hive.spawn({ bee, cwd, name, home, node, colony, swarmId })
ctx.hive.send(target, text)
ctx.hive.brief(target, text)
ctx.hive.wait(target, { idleMs, timeoutMs })
ctx.hive.waitForSeal(target, { timeoutMs, pollMs })
ctx.hive.kill(target)
ctx.hive.seal(target, artifactPath)
ctx.hive.log(message)
```

These calls deliver prompts or control native harness sessions. If the prompt text includes a harness-native command such as `/goal` or `/loop`, Hive passes it through; the selected harness interprets it. Document required harness support in the flow description or args.

Runtime facade extras available in current implementation:

```ts
ctx.hive.collect(target)
ctx.hive.buzSend(target, body, { sender, tier, subject })
ctx.hive.buzInbox(target)
ctx.hive.buzAwait(target, { timeoutMs, pollMs })
ctx.hive.loop({ bee, cwd, context, prompt, until, max, maxDuration, forever, stopOnSeal, stopOnSentinel, judge, summarizer, yolo })
ctx.hive.loopStatus(loopId)
ctx.hive.loopStop(loopId, { now })
```

Use extras in TS flows only; JSON flows only know the core facade.

## Cleanup

`cleanup: "keep"` is default. Spawned bees remain inspectable.

`cleanup: "kill-on-end"` kills bees spawned by that flow on success, cancel, or failure. Use it for clean production runs, not for first proofs.

## Background Runs

`hive flow run --background` starts a detached process group. `hive flow cancel <runId>` signals the group. Flow logs and result metadata are persisted under the flow run directory.

Flow code should honor `ctx.signal` around long custom loops:

```ts
if (ctx.signal?.aborted) throw new Error("flow aborted");
```

## Bounded Parallel Helper Pattern

```ts
async function mapLimit<T, R>(items: T[], limit: number, fn: (item: T, index: number) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const index = next++;
      out[index] = await fn(items[index]!, index);
    }
  });
  await Promise.all(workers);
  return out;
}
```

Use this instead of `Promise.all(shards.map(...))` for large shard counts.

## Flow Plus Loop

Starting a loop from a flow:

```ts
const loopId = await ctx.hive.loop({
  bee: "codex",
  cwd,
  context: "rolling",
  prompt: "Process the next shard from queue.jsonl and seal.",
  max: 100,
  until: "node scripts/queue-empty.js",
  summarizer: "self",
});
await ctx.hive.log(`started loop ${loopId}`);
```

Monitor separately:

```sh
hive loop status <loopId>
hive loop logs <loopId> -f
hive loop stop <loopId>
```
