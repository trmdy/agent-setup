#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sync-agents.sh [--harness NAME ...] [--all] [--dry-run|-n] [--verbose|-v]

Copies repo root AGENTS.md to harness root folders listed in locations.json.

Defaults:
  harnesses: codex opencode

Env:
  AGENTS_SRC      override source AGENTS.md (default: repo root)
  LOCATIONS_JSON  override locations.json (default: repo root)
  AGENTS_HOME     base for relative paths (default: $HOME)
USAGE
}

dry_run=0
verbose=0
all=0
harnesses=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness)
      harnesses+=("${2:-}"); shift 2 ;;
    --all)
      all=1; shift ;;
    -n|--dry-run)
      dry_run=1; shift ;;
    -v|--verbose)
      verbose=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "unknown arg: $1" >&2
      usage; exit 2 ;;
  esac
done

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_src="${AGENTS_SRC:-$root_dir/AGENTS.md}"
locations_json="${LOCATIONS_JSON:-$root_dir/locations.json}"
agents_home="${AGENTS_HOME:-$HOME}"

if [[ ! -f "$agents_src" ]]; then
  echo "missing AGENTS.md: $agents_src" >&2
  exit 1
fi
if [[ ! -f "$locations_json" ]]; then
  echo "missing locations.json: $locations_json" >&2
  exit 1
fi

if [[ $all -eq 1 ]]; then
  harnesses=("__ALL__")
elif [[ ${#harnesses[@]} -eq 0 ]]; then
  harnesses=("codex" "opencode")
fi

python_code=$(cat <<'PY'
import json
import os
import sys

locations_file = sys.argv[1]
home = sys.argv[2]
requested = sys.argv[3:]

with open(locations_file, "r", encoding="utf-8") as f:
  data = json.load(f)

by_name = {h["name"]: h["paths"] for h in data.get("harnesses", [])}

if not requested or "__ALL__" in requested:
  wanted = list(by_name.keys())
else:
  wanted = requested
  missing = [h for h in wanted if h not in by_name]
  if missing:
    print(f"unknown harness: {', '.join(missing)}", file=sys.stderr)
    sys.exit(2)

paths = []
for name in wanted:
  for p in by_name.get(name, []):
    paths.append(p if os.path.isabs(p) else os.path.join(home, p))

seen = set()
for p in paths:
  if p in seen:
    continue
  seen.add(p)
  print(p)
PY
)

dests=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  dests+=("$line")
done < <(
  python3 -c "$python_code" "$locations_json" "$agents_home" "${harnesses[@]}"
)

sync_one() {
  local dest_root="$1"
  if [[ ! -d "$dest_root" ]]; then
    echo "skip: missing $dest_root"
    return 0
  fi
  if [[ $dry_run -eq 1 ]]; then
    echo "dry-run: $agents_src -> $dest_root/AGENTS.md"
    return 0
  fi
  cp "$agents_src" "$dest_root/AGENTS.md"
  [[ $verbose -eq 1 ]] && echo "synced $dest_root"
}

for d in "${dests[@]}"; do
  sync_one "$d"
done
