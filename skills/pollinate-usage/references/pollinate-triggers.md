# Pollinate Trigger Reference

## Contents

- CLI Basics
- Trigger Shape
- Sources
- Delivery
- Filters
- Context
- Daemon
- Webhook Satellites And Temporary Hooks

## CLI Basics

`pollinate` and `pol` are equivalent when linked or installed.

```sh
pol add ./trigger.toml
pol create hello --source manual --action command --command 'echo hello'
pol list --enabled
pol get hello
pol enable hello
pol disable hello
pol edit hello
pol remove hello
pol trigger hello --payload '{"manual":true}'
pol trigger hello --payload '{"manual":true}' --dry-run
pol status
pol ledger -n 100
pol jobs --last 20
pol job <jobId>
pol job cancel <jobId>
```

## Trigger Shape

```toml
[trigger]
id = "morning-audit"
name = "Morning audit"
description = "Run a hive flow every weekday"
enabled = true
cwd = "/Users/me/src/repo"
tags = ["audit", "hive"]

[trigger.source]
kind = "schedule"

[trigger.delivery]
mode = "immediate"
maxConcurrent = 1

[trigger.context.static]
target = "src"

[trigger.action]
kind = "honeybee"
run = "flow"
flow = "audit-flow"

[trigger.action.args]
target = "{{target}}"
```

The unifying model is:

```text
trigger = source + filter? + delivery + context? + action/router
```

## Sources

Manual:

```sh
pol create manual-audit --source manual --action command --command 'echo {{event}}'
```

Schedule:

```sh
pol create every-five --source schedule --every 5m --action command --command 'date'
pol create weekday-8 --source schedule --cron '0 8 * * 1-5' --timezone Europe/Oslo --action command --command 'date'
pol create one-shot --source schedule --once '2026-06-10T08:00:00+02:00' --action command --command 'date'
```

Missed fire policy supports `skip`, `fire-once`, and `fire-all` on schedule timings.

Poll:

```sh
pol create hive-ledger-poll --source poll --poll-interval 30s \
  --fetch-file "$HOME/.hive/ledger.jsonl" --cursor append-offset --emit per-item \
  --action emit --subject hive.ledger.item --payload '{{event}}'

pol create command-poll --source poll --poll-interval 1m \
  --fetch-command 'gh pr list --json number,updatedAt' --cursor-jsonpath '$[*].updatedAt' \
  --action honeybee-flow --flow pr-audit
```

Poll fetch kinds are command, HTTP, and file. Cursor strategies are `append-offset`, `hash`, and `jsonpath`. Emission is `per-item` or `per-poll`.

Webhook:

```sh
pol create callback --source webhook --path callbacks/build \
  --secret env:BUILD_WEBHOOK_SECRET \
  --transform status='$.status' --transform url='$.html_url' \
  --action emit --subject build.callback --payload '{{event}}'
```

The daemon serves webhook triggers at `/hook/<path>`.

## Delivery

Immediate:

```sh
--delivery immediate --max-concurrent 1
```

Throttled:

```sh
--delivery throttled --delivery-interval 10m --collect --max-concurrent 1
```

If `--collect` is set, suppressed activations are accumulated and fired as a batch at the throttle boundary.

Batched:

```sh
--delivery batched --window 2m --max-batch 20 --max-concurrent 2
```

Debounced:

```sh
--delivery debounced --quiet-period 90s --max-concurrent 1
```

Rendered context includes `{{batch}}` and `{{batch_count}}`. Use these instead of inventing custom batching fields.

## Filters

Use filters to drop activations before delivery:

```sh
pol create release-hook --source webhook --path release \
  --filter action=published --action command --command 'echo release {{event}}'
```

`--filter key=value` parses JSON-like values; `true` means "field exists".

## Context

Auto variables:

- `trigger_id`
- `fired_at`
- `source_kind`
- `event`
- `batch`
- `batch_count`

CLI static vars:

```sh
pol create audit --source manual --static repo=pollinate --action command --command 'echo {{repo}} {{event}}'
```

Full context resolver in TOML/JSON supports parallel sources:

```json
{
  "static": { "repo": "pollinate" },
  "sources": [
    { "var": "branch", "kind": "command", "command": "git branch --show-current" },
    { "var": "hive_status", "kind": "honeybee", "query": "ps --wide" },
    { "var": "readme", "kind": "file", "path": "README.md" }
  ]
}
```

Use `--context-json '<json>'` for complex context from CLI, or author TOML directly.

## Daemon

Foreground:

```sh
pol daemon run --foreground
```

Service:

```sh
pol daemon install
pol daemon start
pol daemon status
pol daemon logs --lines 200
pol daemon restart
pol daemon stop
```

The daemon reloads trigger files automatically. `triggerReloadMs` defaults to 1000 ms and can be changed in `pollinate.toml`.

## Webhook Satellites And Temporary Hooks

Temporary:

```sh
pol hook create callback --ttl 15m --once --action emit --subject callback.received
pol hook inbox --ttl 1h
pol hook wait --ttl 10m
pol hook gc
pol hooks
```

Satellite:

```sh
POLLINATE_RELAY_SECRET='same-secret-as-local' \
pol satellite run --bind 0.0.0.0 --port 3979 \
  --target http://workstation-name:3978 \
  --secret env:POLLINATE_RELAY_SECRET
```

Local daemon config:

```toml
[webhook]
bind = "127.0.0.1"
port = 3978
publicUrl = "https://vps.example.com"

[webhook.relay]
secret = "env:POLLINATE_RELAY_SECRET"
maxAgeSeconds = 300
```
