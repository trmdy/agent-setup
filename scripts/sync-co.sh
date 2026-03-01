#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sync-co.sh [push|pull] [--dry-run|-n] [--verbose|-v]

Copies templates/ and partials/ between this repo and ~/Code/_system.

Modes:
  push  (default)  repo -> ~/Code/_system
  pull             ~/Code/_system -> repo

Env:
  CO_SYSTEM_ROOT   override target root (default: ~/Code/_system)
USAGE
}

mode="push"
dry_run=0
verbose=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    push|pull)
      mode="$1"; shift ;;
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
src_partials="$root_dir/partials"
src_templates="$root_dir/templates"

dest_root="${CO_SYSTEM_ROOT:-$HOME/Code/_system}"
dest_partials="$dest_root/partials"
dest_templates="$dest_root/templates"

rsync_opts=(-a --human-readable --itemize-changes)
[[ $dry_run -eq 1 ]] && rsync_opts+=(--dry-run)
[[ $verbose -eq 1 ]] && rsync_opts+=(--progress)

sync_dir() {
  local src="$1"
  local dst="$2"
  if [[ ! -d "$src" ]]; then
    echo "skip: missing $src"
    return 0
  fi
  mkdir -p "$dst"
  rsync "${rsync_opts[@]}" "$src/" "$dst/"
}

if [[ "$mode" == "push" ]]; then
  sync_dir "$src_partials" "$dest_partials"
  sync_dir "$src_templates" "$dest_templates"
else
  sync_dir "$dest_partials" "$src_partials"
  sync_dir "$dest_templates" "$src_templates"
fi
