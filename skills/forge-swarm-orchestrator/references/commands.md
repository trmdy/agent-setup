# Forge Swarm Command Templates

Replace placeholders before use.

## 0) Variables
```bash
REPO="<ABS_REPO_PATH>"
PROJECT_ID="<SV_PROJECT_ID>"
PROFILE="<FORGE_PROFILE>"
PROMPT_FILE="<PROMPT_FILE_PATH>"
TAG="<SWARM_TAG>"
QSTOP="/Users/trmd/Code/oss--forge/repos/forge/scripts/swarm-quant-stop.sh"
```

## 1) Preflight
```bash
forge --robot-help
forge up --help
forge ps --help
sv --robot-help
sv task --robot-help

sv task count --project "$PROJECT_ID" --status open
sv task count --project "$PROJECT_ID" --status in_progress
```

## 2) Prompt strategy
Preferred if prompt registry is healthy:
```bash
forge -C "$REPO" prompt add "${TAG}-dev" "$PROMPT_FILE"
PROMPT_ARGS=(--prompt "${TAG}-dev")
```
Fallback when named prompt behaves inconsistently:
```bash
PROMPT_ARGS=(--prompt-msg "$(cat "$PROMPT_FILE")")
```

## 3) Single-loop proof (required)
```bash
forge -C "$REPO" up \
  --count 1 \
  --name "${TAG}-proof-$(date +%Y%m%d-%H%M%S)" \
  --profile "$PROFILE" \
  --spawn-owner daemon \
  --interval 2m \
  --max-iterations 1 \
  --max-runtime 1h \
  --tags "$TAG" \
  "${PROMPT_ARGS[@]}" \
  --quantitative-stop-cmd "$QSTOP --project $PROJECT_ID --open-max 0 --in-progress-max 0 --quiet" \
  --quantitative-stop-exit-codes 0 \
  --quantitative-stop-decision stop \
  --quantitative-stop-when before \
  --quantitative-stop-every 1
```

## 4) Daemon-ownership gate (mandatory)
```bash
forge ps --repo "$REPO" --tag "$TAG" --json | jq -r \
  '.[] | "\(.short_id) owner=\(.runner_owner) pid=\(.runner_pid_alive) daemon=\(.runner_daemon_alive) state=\(.state)"'
```
Expected pattern for healthy swarm loops:
- `owner=daemon`
- `pid=true`
- `daemon=true`

If any loop shows `owner=local`, treat as failed swarm spawn:
```bash
forge stop --repo "$REPO" --tag "$TAG"
forge kill --repo "$REPO" --tag "$TAG"   # fallback if stop hangs
# respawn with --spawn-owner daemon
```

## 5) Controlled ramp-up
After proof loop passes:
```bash
forge -C "$REPO" up \
  --count 2 \
  --name-prefix "${TAG}-dev-$(date +%Y%m%d-%H%M%S)" \
  --profile "$PROFILE" \
  --spawn-owner daemon \
  --interval 2m \
  --max-iterations 0 \
  --max-runtime 3h \
  --tags "$TAG" \
  "${PROMPT_ARGS[@]}" \
  --quantitative-stop-cmd "$QSTOP --project $PROJECT_ID --open-max 0 --in-progress-max 0 --quiet" \
  --quantitative-stop-exit-codes 0 \
  --quantitative-stop-decision stop \
  --quantitative-stop-when before \
  --quantitative-stop-every 1
```

## 6) Health checks
```bash
forge ps --repo "$REPO" --tag "$TAG"

for id in $(forge ps --repo "$REPO" --tag "$TAG" --json | jq -r '.[].short_id'); do
  forge logs "$id" -n 120 --compact
done

forge ps --repo "$REPO" --tag "$TAG" --json | jq -r \
  '.[] | "\(.short_id) \(.state) owner=\(.runner_owner) runs=\(.runs)"'

sv task count --project "$PROJECT_ID" --status open
sv task count --project "$PROJECT_ID" --status in_progress
sv task ready --project "$PROJECT_ID"
```

## 7) Dogpile checks
```bash
sv task list --project "$PROJECT_ID" --status in_progress
fmail log task -n 200 | rg 'claim:'
forge msg --repo "$REPO" --tag "$TAG" "Pick OPEN/READY first. IN_PROGRESS only self-owned or stale takeover >=45m."
```

## 8) Wind-down
```bash
forge stop --repo "$REPO" --tag "$TAG"
forge ps --repo "$REPO" --tag "$TAG" --json | jq -r '.[] | "\(.short_id) \(.state)"'
```
Hard-stop fallback:
```bash
forge kill --repo "$REPO" --tag "$TAG"
```

## 9) Post-stop sync
```bash
sv task sync
sv project sync
```
