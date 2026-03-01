#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  linear_graphql.sh --query-file PATH [--variables-file PATH] [--project NAME] [--secret NAME] [--endpoint URL]

Options:
  --query-file PATH      GraphQL query/mutation file (required)
  --variables-file PATH  JSON object file for GraphQL variables (optional)
  --project NAME         Hem project scope (default: digitech)
  --secret NAME          Hem secret name (default: linear)
  --endpoint URL         Linear GraphQL endpoint (default: https://api.linear.app/graphql)
  -h, --help             Show help

Notes:
  - Token is resolved from hem secret ref: project/<project>/<secret>.
  - Script never prints the token.
  - Exits non-zero when GraphQL returns top-level errors.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

project="digitech"
secret="linear"
endpoint="https://api.linear.app/graphql"
query_file=""
variables_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query-file)
      query_file="${2:-}"
      shift 2
      ;;
    --variables-file)
      variables_file="${2:-}"
      shift 2
      ;;
    --project)
      project="${2:-}"
      shift 2
      ;;
    --secret)
      secret="${2:-}"
      shift 2
      ;;
    --endpoint)
      endpoint="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown arg: $1"
      ;;
  esac
done

[[ -n "$query_file" ]] || die "--query-file is required"
[[ -f "$query_file" ]] || die "query file not found: $query_file"
[[ -z "$variables_file" || -f "$variables_file" ]] || die "variables file not found: $variables_file"

secret_ref="project/$project/$secret"

secret_dump="$(hem get "$secret_ref")" || die "hem get failed for $secret_ref"

token=""
while IFS= read -r line; do
  key="${line%%=*}"
  value="${line#*=}"
  case "$key" in
    api_key|token|linear_api_key|LINEAR_API_KEY)
      token="$value"
      break
      ;;
  esac
done <<< "$secret_dump"

[[ -n "$token" ]] || die "no token-like key found in $secret_ref (expected api_key/token)"

payload="$(python3 - "$query_file" "$variables_file" <<'PY'
import json
import pathlib
import sys

query_path = pathlib.Path(sys.argv[1])
vars_path = sys.argv[2] if len(sys.argv) > 2 else ""

query = query_path.read_text(encoding="utf-8")
variables = {}

if vars_path:
    raw = pathlib.Path(vars_path).read_text(encoding="utf-8").strip()
    if raw:
        variables = json.loads(raw)
        if not isinstance(variables, dict):
            raise SystemExit("variables JSON must be an object")

print(json.dumps({"query": query, "variables": variables}, separators=(",", ":")))
PY
)"

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

curl --fail-with-body -sS "$endpoint" \
  -H "Content-Type: application/json" \
  -H "Authorization: $token" \
  --data "$payload" \
  > "$response_file"

cat "$response_file"

python3 - "$response_file" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    payload = json.load(f)

if payload.get("errors"):
    raise SystemExit(2)
PY
