#!/usr/bin/env bash
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_name="$(basename "$skill_dir")"

targets=(
  "$HOME/.codex-1/skills"
  "$HOME/.codex-2/skills"
  "$HOME/.codex-3/skills"
  "$HOME/.cc1/skills"
  "$HOME/.cc2/skills"
  "$HOME/.cc3/skills"
  "$HOME/.oc1/skills"
  "$HOME/.oc2/skills"
  "$HOME/.oc3/skills"
)

for root in "${targets[@]}"; do
  mkdir -p "$root"
  target="$root/$skill_name"

  if [[ "$target" == "$skill_dir" ]]; then
    echo "skip self: $target"
    continue
  fi

  if [[ -L "$target" && "$(readlink "$target")" == "$skill_dir" ]]; then
    echo "ok already linked: $target"
    continue
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$target" "$backup"
    echo "moved existing -> $backup"
  fi

  ln -s "$skill_dir" "$target"
  echo "linked $target -> $skill_dir"
done
