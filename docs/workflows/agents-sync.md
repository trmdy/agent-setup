# AGENTS Sync

Goal: keep root `AGENTS.md` synced to harness roots listed in `locations.json`.

Steps
1. Update root `AGENTS.md`.
2. Dry-run: `scripts/sync-agents.sh -n --harness codex --harness opencode`.
3. Run: `scripts/sync-agents.sh --harness codex --harness opencode`.
4. Optional spot-check: `diff -u AGENTS.md ~/.codex-1/AGENTS.md`.

Variants
- All harnesses: `scripts/sync-agents.sh --all`.
- Verbose: `scripts/sync-agents.sh -v ...`.
- Custom inputs: set `AGENTS_SRC`, `LOCATIONS_JSON`, `AGENTS_HOME`.
