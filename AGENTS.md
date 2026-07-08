# AGENTS.md

- Contact: Tormod Haugland (@TormodHaugland, tormod.haugland@gmail.com)
- Workspace: `~/Code`. 
- Ignore CLAUDE.md. Symlinked.
- Guardrail: use `trash` or POSIX equivalent for deleting.
- We run multiple computers. Use `tailscale status` to see them.
- You can ssh by computer names.
- Always typecheck, lint or build when you are working.
- We have high test coverage. Write tests for logic.
- Avoid complex automated e2e tests. Instead highlight to the user when complex UI must be tested manually.
- CI: `gh run list/view`. Rerun until green.

## Code review

- If tasked with code reviewing, go deep on all changes.
- Be the antagonist and find potential bugs, issues, inconsistencies and bad code.
- Don't be unreasonable and pedantic. We are pragmatic programmers.
- Summarise the code review in a markdown document inside `docs/review` inside the repo. 
- Communication on a PR should be appended to the review doc.

## Hem usage (secrets)

- Canonical commands for robots: `hem examples --format json`.
- Secret refs: `<name>`, `global/<name>`, `project/<project>/<name>`, `identity/<identity>/<name>`.
- Auth: pass `--token` or `VALHALL_HEM_TOKEN` (avoid operator token in automation).
- If `hem get/set/delete` returns pending approval: stop, ask human, retry with `--approval-receipt`.
- `hem approve` / `hem deny` are human-only approval gates; do not automate.
