#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sync-skills.sh [--harness NAME ...] [--all] [--copy] [--dry-run|-n] [--verbose|-v]

Syncs skills from repo ./skills into each harness root's ./skills path from locations.json.
Default mode uses symlinks (single source of truth).

Defaults:
  harnesses: codex

Env:
  SKILLS_SRC      override source skills dir (default: repo root /skills)
  LOCATIONS_JSON  override locations file (default: repo root /locations.json)
  AGENTS_HOME     base for relative harness paths (default: $HOME)
USAGE
}

dry_run=0
verbose=0
all=0
copy_mode=0
harnesses=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness)
      harnesses+=("${2:-}"); shift 2 ;;
    --all)
      all=1; shift ;;
    --copy)
      copy_mode=1; shift ;;
    -n|--dry-run)
      dry_run=1; shift ;;
    -v|--verbose)
      verbose=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 2 ;;
  esac
done

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_src="${SKILLS_SRC:-$root_dir/skills}"
locations_json="${LOCATIONS_JSON:-$root_dir/locations.json}"
agents_home="${AGENTS_HOME:-$HOME}"

if [[ ! -d "$skills_src" ]]; then
  echo "missing skills dir: $skills_src" >&2
  exit 1
fi
if [[ ! -f "$locations_json" ]]; then
  echo "missing locations.json: $locations_json" >&2
  exit 1
fi

if [[ $all -eq 1 ]]; then
  harnesses=("__ALL__")
elif [[ ${#harnesses[@]} -eq 0 ]]; then
  harnesses=("codex")
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
done < <(python3 -c "$python_code" "$locations_json" "$agents_home" "${harnesses[@]}")

skill_dirs=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  skill_dirs+=("$line")
done < <(find "$skills_src" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | sort)

if [[ ${#skill_dirs[@]} -eq 0 ]]; then
  echo "no skills found in $skills_src"
  exit 0
fi

backup_path() {
  local p="$1"
  echo "${p}.bak.$(date +%Y%m%d%H%M%S)"
}

sync_one_dest() {
  local harness_root="$1"
  local harness_skills="$harness_root/skills"

  if [[ ! -d "$harness_root" ]]; then
    echo "skip: missing harness root $harness_root"
    return 0
  fi

  if [[ $dry_run -eq 1 ]]; then
    echo "dry-run: ensure $harness_skills"
  else
    mkdir -p "$harness_skills"
  fi

  for src in "${skill_dirs[@]}"; do
    local name
    name="$(basename "$src")"
    local dest="$harness_skills/$name"

    if [[ -L "$dest" ]]; then
      local target
      target="$(readlink "$dest")"
      if [[ "$target" == "$src" ]]; then
        [[ $verbose -eq 1 ]] && echo "ok: $dest -> $src"
        continue
      fi
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
      local bak
      bak="$(backup_path "$dest")"
      if [[ $dry_run -eq 1 ]]; then
        echo "dry-run: mv $dest $bak"
      else
        mv "$dest" "$bak"
      fi
    fi

    if [[ $copy_mode -eq 1 ]]; then
      if [[ $dry_run -eq 1 ]]; then
        echo "dry-run: cp -R $src $dest"
      else
        cp -R "$src" "$dest"
      fi
    else
      if [[ $dry_run -eq 1 ]]; then
        echo "dry-run: ln -s $src $dest"
      else
        ln -s "$src" "$dest"
      fi
    fi

    [[ $verbose -eq 1 ]] && echo "synced: $dest"
  done
}

for d in "${dests[@]}"; do
  sync_one_dest "$d"
done
