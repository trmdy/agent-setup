# Dynamic Workflow Pattern Catalog

## Contents

- When To Generate A Workflow
- Core Patterns
- Use Case Recipes
- Budgets And Stop Conditions
- Saving And Sharing
- Prompt Nudges

## When To Generate A Workflow

Generate a task-specific harness when a single agent context is likely to fail because work is long-running, highly parallel, adversarial, repetitive, or structurally large. The workflow should hold the deterministic control loop while spawned agents get clean, focused contexts.

When using Hive as the workflow substrate, remember that each spawned bee is still a native harness session. You can compose Hive-level orchestration with harness-native features such as Claude Code `/goal` and `/loop` where supported. Keep the requirement explicit so a Codex, Grok, or other bee is not asked to run a Claude-specific command by accident.

Dynamic workflows are useful against these failure modes:

- Partial completion: the agent stops after a subset of a large task.
- Self-preferential bias: the agent over-trusts its own findings.
- Goal drift: compaction or long context loses constraints and edge cases.

Avoid dynamic workflows for normal small coding tasks unless the user asks for a quick workflow or an adversarial check. Extra agents increase token and tool cost.

## Core Patterns

Classify-and-act:

- Spawn a classifier to inspect the input and choose route, model, harness, or shard type.
- Dispatch specialized workers based on the classifier output.
- Optionally classify final outputs into accept/retry/escalate buckets.

Fan-out-and-synthesize:

- Split the input into independent shards.
- Spawn one worker per shard or a bounded worker pool.
- Wait at a barrier until structured outputs arrive.
- Spawn a synthesizer to merge results and call out missing shards.

Adversarial verification:

- Pair each worker output with a separate verifier.
- Give the verifier the rubric and the raw evidence, not the worker's confidence.
- Require explicit accept/reject/retry with reasons.

Generate-and-filter:

- Spawn many idea generators with varied prompts or constraints.
- Deduplicate and score against a rubric.
- Verify the finalists before returning them.

Tournament:

- Spawn multiple agents to solve the same problem with different approaches.
- Use pairwise judging or bracket rounds rather than absolute scoring.
- Preserve judging criteria outside the competing agents.

Loop-until-done:

- Use when the amount of work is unknown.
- Repeat bounded passes until a mechanical stop fires: no new findings, tests pass, queue empty, no errors, or max iterations.
- Prefer `hive loop start` or a TS flow that starts loops for continuous queues.

Quarantine triage:

- Separate untrusted-content readers from high-privilege actors.
- Reader agents classify/summarize public content.
- Action agents receive sanitized outputs and perform privileged changes.

Model/intelligence routing:

- Spawn a lightweight classifier to estimate complexity, tool depth, and required isolation.
- Route simple tasks to cheaper/faster bees and complex tasks to stronger bees.
- Record routing decisions so a reviewer can audit cost/quality tradeoffs.

## Use Case Recipes

Flaky test investigation:

- Generate hypotheses from logs, code, and runtime behavior in separate agents.
- Test each hypothesis in isolated worktrees or fresh checkouts when available.
- Run refuters against the strongest hypotheses.
- Stop only when a reproduction or fix passes repeated runs.

Deep research:

- Fan out source discovery.
- Fetch and summarize sources.
- Verify claims against primary evidence.
- Synthesize a cited report with a separate reviewer checking source quality.

Deep verification:

- Extract factual or technical claims from a report.
- Spawn one verifier per claim or claim cluster.
- Spawn a second-level verifier for high-impact claims.
- Return only claims with source-backed status.

Sorting and ranking:

- Avoid scoring 1000 items in one context.
- Use bucket ranking, pairwise comparisons, or tournament brackets.
- Merge buckets and re-check the top slice.

Memory/rule mining:

- Mine prior sessions or reviews for corrections.
- Cluster recurring corrections.
- Verify whether each candidate rule would have prevented a real mistake.
- Distill survivors into the target rules file.

Root-cause investigation:

- Separate evidence agents by source: logs, code, data, incidents, timeline.
- Generate independent hypotheses.
- Run refuters and verifiers.
- Synthesize causes with confidence and unresolved evidence gaps.

Exploration and taste:

- Generate many options independently.
- Judge with a rubric.
- Use tournament or panel review for final candidates.

Evals:

- Spawn isolated agents for candidate outputs.
- Spawn graders to compare against rubric and examples.
- Feed findings back into skill/rule/prompt improvements.

## Budgets And Stop Conditions

Every generated workflow should state:

- max spawned agents or worker concurrency
- max iterations
- timeout per worker and total wall-clock timeout
- expected expensive commands to avoid or cap
- model/bee kind routing policy
- success criteria
- retry/escalation criteria

For Hive, encode these with flow args, bounded `mapLimit`, `hive loop --max`, `--max-duration`, `--until`, Pollinate `maxConcurrent`, and delivery batching/debouncing.

## Saving And Sharing

Saved Hive flows should live as source files in the repo or skill:

- JSON for linear templates.
- TypeScript for dynamic orchestration.
- References should tell agents to treat templates as adaptable harnesses, not scripts to run verbatim.

Register saved flows with:

```sh
hive flow define ./path/to/flow.ts
```

Distribute reusable templates through a skill by putting the flow source in the skill resources or references and linking it from `SKILL.md`.

## Prompt Nudges

Useful phrasing:

```text
Create a quick workflow: fan out three independent reviewers, then synthesize.
```

```text
Use a workflow with adversarial verification. Each worker result gets a separate verifier.
```

```text
Use a tournament workflow. Generate many options, run pairwise judging, return the top three.
```

```text
Use a loop-until-done workflow with a hard budget: max 20 workers, max 5 iterations, stop when tests pass.
```
