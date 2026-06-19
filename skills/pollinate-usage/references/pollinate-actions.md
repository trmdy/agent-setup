# Pollinate Actions And Routers

## Contents

- Action Kinds
- Honeybee Actions
- Sequence Actions
- GitHub PR Router
- User-Space Router Plugins
- Execution Profile

## Action Kinds

Command:

```sh
pol create cmd --source manual --action command --command 'echo {{event}}' --timeout 30s
```

HTTP:

```sh
pol create post --source manual --action http --method POST --url https://example.com/hook \
  --header 'content-type=application/json' --body '{{event}}'
```

Emit:

```sh
pol create emit-example --source manual --action emit --subject audit.started --payload '{"event":{{event}}}'
```

Hermes:

```sh
pol create hermes-job --source schedule --every 1h --action hermes --invoke run-audit --payload '{{event}}'
```

If `invoke` starts with `http://` or `https://`, Pollinate POSTs JSON. Otherwise it runs `hermes <invoke>` and passes the payload on stdin.

## Honeybee Actions

Flow:

```sh
pol create flow-job --source schedule --every 1h --cwd "$PWD" \
  --action honeybee-flow --flow deep-review --arg target=src
```

Runs `hive flow run <flow> --arg key=value`.

Loop:

```sh
pol create loop-job --source manual --cwd "$PWD" \
  --action honeybee-loop \
  --loop bee=codex --loop cwd="$PWD" --loop context=rolling \
  --loop max=50 --loop prompt='Work the next item and seal.'
```

Runs `hive loop start` with flags from the loop record.

Spawn:

```sh
pol create spawn-reviewer --source webhook --path pr/review --cwd "$PWD" \
  --action honeybee-spawn --bee codex --name 'review-{{pr_number}}' \
  --message 'Review PR {{pr_number}}: {{pr_title}}' --yolo
```

Pollinate parses the spawned hive handle from stdout and stores it in the job result. If `message` is present, Pollinate sends it after spawn.

The message is delivered through Hive into the native harness. It may include harness-native commands such as `/goal` or `/loop` when the selected bee supports them; document and verify that requirement per trigger.

Send:

```sh
pol create notify-bee --source manual --action honeybee-send \
  --target CO.a3f --message 'New event: {{event}}'
```

Buz:

```sh
pol create queued-note --source manual --action honeybee-buz \
  --target CO.a3f --tier queue --sender-human pollinate \
  --subject event.received --message 'Payload: {{event}}'
```

Kill:

```sh
pol create kill-reviewer --source manual --action honeybee-kill --target CO.a3f
```

## Sequence Actions

Use `--action-json` for serial or parallel orchestration. Parallel sequences are useful for fanning one event into multiple Honeybee actions.

```json
{
  "kind": "sequence",
  "mode": "parallel",
  "primary": "codex",
  "continueOnError": false,
  "actions": [
    {
      "id": "codex",
      "action": {
        "kind": "honeybee",
        "run": "spawn",
        "bee": "codex",
        "cwd": "{{repo_dir}}",
        "message": "Review {{event}}"
      }
    },
    {
      "id": "grok",
      "action": {
        "kind": "honeybee",
        "run": "spawn",
        "bee": "grok",
        "cwd": "{{repo_dir}}",
        "message": "Challenge the Codex review for {{event}}"
      }
    }
  ]
}
```

Sequence results aggregate `handle` and `handles` fields from child Honeybee spawn actions. Router bindings can store those handles.

## GitHub PR Router

Use routers when many external events must map to one long-lived hive target.

Fast path:

```sh
pol github create-pr-router repo-pr-router \
  --repo Owner/repo \
  --cwd /Users/me/src/repo \
  --secret env:GITHUB_WEBHOOK_SECRET \
  --base-url https://hooks.example.com \
  --install-webhook
```

Multi-reviewer router:

```sh
pol github create-pr-router repo-pr-router \
  --repo Owner/repo \
  --cwd /Users/me/src/repo \
  --secret env:GITHUB_WEBHOOK_SECRET \
  --reviewer codex=codex \
  --reviewer grok=grok
```

Binding lifecycle:

1. Webhook arrives at `/hook/<path>`.
2. Router plugin normalizes event to `subjectKey` plus `kind`.
3. First `openOn` event runs `onOpen` and stores target handle(s).
4. Later activity renders `onActivity` with `{{binding.target}}` and `{{binding.targets.<id>}}`.
5. Close event runs `onClose` and marks binding closed.

Inspect:

```sh
pol bindings --trigger repo-pr-router
pol bindings get <bindingId>
pol jobs --trigger repo-pr-router --last 20
```

Loop prevention for PR comment bots: include `<!-- pollinate-router -->` in comments posted by router-controlled bees so the GitHub PR plugin ignores self-generated comments.

Common GitHub fields include:

```text
repo
repo_owner
repo_name
repo_slug
pr_number
pr_url
pr_title
pr_state
event_kind
action
actor
activity_markdown
activity_url
comment_body
review_body
review_state
check_name
check_status
check_conclusion
binding.target
binding.targets.<id>
```

## User-Space Router Plugins

```sh
pol routers list
pol routers init my-router
```

Plugins live under `~/.pollinate/router-plugins/<name>.mjs`. They should only normalize raw provider payloads into canonical events. Keep lifecycle and target control in Pollinate router config.

## Execution Profile

Set a predictable shell and environment for daemon jobs:

```toml
[execution]
shell = "/bin/zsh"
shellArgs = ["-lc"]
inheritEnv = true

[execution.env]
PATH = "/Users/me/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

Do this before relying on `gh`, `hive`, `node`, `pnpm`, or project scripts from daemon-triggered jobs.
