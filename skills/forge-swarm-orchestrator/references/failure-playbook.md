# Forge Swarm Failure Playbook

## Symptom: loops stop right after spawn/run start
Checks:
- `forge ps --json` shows `runner_owner=local`.
- `runs` increments once, then loop is stopped.
- `runner_pid_alive=false`, `runner_daemon_alive=false`.
Fix:
- Respawn with explicit `--spawn-owner daemon`.
- Verify owner gate before ramp-up.
- Stop/kill bad local-owned loops.

## Symptom: loop "running" but no work
Checks:
- Logs show immediate idle/exit.
- Prompt references missing external/base prompt.
- Task query returns none due to wrong project/filter.
Fix:
- Inline required base prompt text.
- Run one-loop proof with full args.
- Verify project/task filters.
- Verify prompt mode (`--prompt` vs `--prompt-msg`) in this environment.

## Symptom: loop dies immediately on spawn
Checks:
- Nested harness/TTY issue.
- Bad profile config or unavailable provider model.
- Profile currently unavailable/contended.
Fix:
- Re-run same command directly (no wrapper script).
- Reduce args to minimum, then add back incrementally.
- Validate profile in harness config.
- Switch to another known-good profile for proof, then retry preferred profile.

## Symptom: quantitative stop always "not matched" with odd exit code
Checks:
- Inline shell quoting errors in `--quantitative-stop-cmd`.
- Exit code `2` from malformed command.
Fix:
- Prefer dedicated helper script:
  - `.../forge/scripts/swarm-quant-stop.sh --project <id> --open-max 0 --in-progress-max 0 --quiet`
- Keep `--quantitative-stop-exit-codes 0` and `--quantitative-stop-when before`.

## Symptom: many loops, little throughput
Checks:
- Concurrency over cap.
- Too many review loops vs dev loops.
- Agents blocked by same file/task.
Fix:
- Lower concurrent dev loops per harness.
- Rebalance role mix.
- Split tasks smaller and reassign.

## Symptom: all loops pile onto one in-progress task (dogpile)
Checks:
- Multiple loops report progress on the same task ID.
- `sv task count --status open` still high.
- Prompt says "prefer in_progress" without ownership/stale rules.
Fix:
- Patch prompt policy: default `open/ready` first.
- Allow `in_progress` only for self-owned or stale takeover (`>=45m` no update).
- Require `claim: <task-id>` messages on pickup.
- Broadcast immediate correction with `forge msg --tag <DEV_TAG> ...`.

## Symptom: tasks closed with weak parity
Checks:
- Missing explicit closure gates in task body.
- No DPC/manual comparison evidence.
Fix:
- Patch task templates with hard gates.
- Reopen tasks without proof artifacts.

## Symptom: data mismatch between old/new app
Checks:
- Different tenant/env selected.
- Sync/export/import pipeline failed.
- Auth guard hides data from one app.
Fix:
- Verify same tenant route and auth mode.
- Re-run sync pipeline with logs.
- Add blocking data-parity task; do not close UI tasks first.

## Global guardrail
- Agents must not push to `main`.
- Swarm loops must be daemon-owned.
