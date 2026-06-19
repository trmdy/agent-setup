# Dynamic Flow Templates

## Contents

- Fan-Out/Fan-In Review
- Two-Phase Debate
- Queue Worker Flow
- Pollinate Trigger For Saved Flow
- Pollinate Webhook To Flow
- Router Instead Of Flow

## Fan-Out/Fan-In Review

```ts
import { defineFlow } from "honeybee/flow";

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

export default defineFlow({
  name: "fanout-fanin-review",
  description: "Shard a review across bounded workers, collect seals, run merger.",
  args: [
    { name: "cwd", default: process.cwd() },
    { name: "shards", default: "src,tests,docs" },
    { name: "concurrency", default: 3 }
  ],
  cleanup: "keep",
  run: async (ctx) => {
    const cwd = String(ctx.args.cwd);
    const shards = String(ctx.args.shards).split(",").map((s) => s.trim()).filter(Boolean);
    const concurrency = Number(ctx.args.concurrency) || 3;
    const swarmId = `review-${ctx.runId}`;

    const results = await mapLimit(shards, concurrency, async (shard) => {
      const bee = await ctx.hive.spawn({ bee: "codex", cwd, colony: "review", swarmId });
      await ctx.hive.brief(bee, [
        `You own shard: ${shard}`,
        "Review only this shard.",
        "Seal JSON with fields: status, shard_id, summary, risks, confidence, artifacts."
      ].join("\n"));
      const seal = await ctx.hive.waitForSeal(bee, { timeoutMs: 1200000 });
      await ctx.hive.log(`sealed shard ${shard} from ${bee.name}`);
      return { shard, bee: bee.name, seal };
    });

    const merger = await ctx.hive.spawn({ bee: "claude", cwd, colony: "review", swarmId });
    await ctx.hive.brief(merger, `Merge these review results and seal a final decision:\n${JSON.stringify(results)}`);
    const merged = await ctx.hive.waitForSeal(merger, { timeoutMs: 1200000 });
    return { swarmId, workerCount: results.length, merger: merger.name, merged };
  },
});
```

## Two-Phase Debate

```ts
import { defineFlow } from "honeybee/flow";

export default defineFlow({
  name: "two-phase-debate",
  args: [{ name: "cwd", default: process.cwd() }, { name: "question" }],
  cleanup: "keep",
  run: async (ctx) => {
    const cwd = String(ctx.args.cwd);
    const question = String(ctx.args.question);
    const swarmId = `debate-${ctx.runId}`;
    const pro = await ctx.hive.spawn({ bee: "codex", cwd, swarmId, colony: "debate" });
    const con = await ctx.hive.spawn({ bee: "grok", cwd, swarmId, colony: "debate" });
    await Promise.all([
      ctx.hive.brief(pro, `Argue for: ${question}. Seal structured argument.`),
      ctx.hive.brief(con, `Argue against: ${question}. Seal structured argument.`),
    ]);
    const [proSeal, conSeal] = await Promise.all([
      ctx.hive.waitForSeal(pro, { timeoutMs: 900000 }),
      ctx.hive.waitForSeal(con, { timeoutMs: 900000 }),
    ]);
    const judge = await ctx.hive.spawn({ bee: "claude", cwd, swarmId, colony: "debate" });
    await ctx.hive.brief(judge, `Judge these arguments and seal final recommendation:\n${JSON.stringify({ proSeal, conSeal })}`);
    const finalSeal = await ctx.hive.waitForSeal(judge, { timeoutMs: 900000 });
    return { swarmId, finalSeal };
  },
});
```

## Queue Worker Flow

```ts
import { defineFlow } from "honeybee/flow";

export default defineFlow({
  name: "queue-worker-pool",
  args: [
    { name: "cwd", default: process.cwd() },
    { name: "workers", default: 5 },
    { name: "max", default: 100 }
  ],
  cleanup: "keep",
  run: async (ctx) => {
    const cwd = String(ctx.args.cwd);
    const workers = Number(ctx.args.workers) || 5;
    const loopIds: string[] = [];
    for (let i = 0; i < workers; i += 1) {
      const loopId = await ctx.hive.loop({
        bee: "codex",
        cwd,
        context: "ralph",
        max: Number(ctx.args.max) || 100,
        until: "node scripts/queue-empty.js",
        prompt: "Claim the next unclaimed queue item, process it, update the queue, and seal."
      });
      loopIds.push(loopId);
      await ctx.hive.log(`started worker loop ${loopId}`);
    }
    return { loopIds };
  },
});
```

## Pollinate Trigger For Saved Flow

```sh
pol create nightly-fanout --source schedule --cron '0 2 * * *' --timezone Europe/Oslo \
  --cwd "$PWD" --delivery immediate --max-concurrent 1 \
  --action honeybee-flow --flow fanout-fanin-review --arg cwd="$PWD" --arg shards=src,tests,docs
```

## Pollinate Webhook To Flow

```sh
pol create webhook-flow --source webhook --path flow/start --secret env:FLOW_WEBHOOK_SECRET \
  --delivery batched --window 1m --max-batch 25 --cwd "$PWD" \
  --action honeybee-flow --flow fanout-fanin-review --arg cwd="$PWD" --arg shards='{{batch}}'
```

## Router Instead Of Flow

Use a router when events share a subject and should keep addressing the same bee:

```sh
pol github create-pr-router repo-pr-router --repo Owner/repo --cwd "$PWD" \
  --secret env:GITHUB_WEBHOOK_SECRET \
  --reviewer codex=codex \
  --reviewer grok=grok
```

Do not make a new standalone flow for every PR comment if the desired behavior is "keep talking to the same PR reviewer".
